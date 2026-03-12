import os
import base64
import io
import re
import tempfile
import threading
import urllib.request
import zipfile
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any
from uuid import uuid4

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from langchain_community.vectorstores import FAISS
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from pydantic import BaseModel, Field
from PyPDF2 import PdfReader

EMBEDDING_MODEL = os.getenv("EMBEDDING_MODEL", "text-embedding-3-small")
CHAT_MODEL = os.getenv("CHAT_MODEL", "gpt-4.1")
VISION_CHAT_MODEL = os.getenv("VISION_CHAT_MODEL", "gpt-4.1-mini")
VECTORSTORE_DIR = Path("vectorstore/faiss_index")
VECTORSTORE_INDEX_PATH = VECTORSTORE_DIR / "index.faiss"
RETRIEVAL_CANDIDATE_K = int(os.getenv("RETRIEVAL_CANDIDATE_K", "18"))
RETRIEVAL_FINAL_K = int(os.getenv("RETRIEVAL_FINAL_K", "10"))
RETRIEVAL_CHARS_PER_CHUNK = int(os.getenv("RETRIEVAL_CHARS_PER_CHUNK", "1100"))


class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=3000)
    history: list[dict[str, str]] = Field(default_factory=list)


class ImageChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=3000)
    image_base64: str = Field(min_length=20)
    mime_type: str = "image/jpeg"
    history: list[dict[str, str]] = Field(default_factory=list)


class ChatResponse(BaseModel):
    answer: str
    used_context: bool
    context_chunks: int


class NoteAttachment(BaseModel):
    name: str = Field(min_length=1, max_length=180)
    base64_data: str = Field(min_length=20)
    mime_type: str = Field(min_length=3, max_length=120)


class NotesGenerationRequest(BaseModel):
    topic: str = Field(min_length=1, max_length=200)
    details: str = Field(default="", max_length=5000)
    attachments: list[NoteAttachment] = Field(default_factory=list)


class NotesGenerationResponse(BaseModel):
    note: str
    attachments_processed: int


class GoogleAuthRequest(BaseModel):
    email: str = Field(min_length=3, max_length=180)
    name: str = Field(min_length=1, max_length=120)
    id_token: str | None = None


class GoogleAuthResponse(BaseModel):
    user_id: str
    email: str
    name: str


class BasicAuthRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    email: str = Field(default="", max_length=180)


class CollabCreateRoomRequest(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    creator_email: str = Field(min_length=3, max_length=180)
    creator_name: str = Field(min_length=1, max_length=120)
    is_public: bool = True


class CollabJoinRoomRequest(BaseModel):
    user_email: str = Field(min_length=3, max_length=180)
    user_name: str = Field(min_length=1, max_length=120)


class CollabMessageRequest(BaseModel):
    user_email: str = Field(min_length=3, max_length=180)
    user_name: str = Field(min_length=1, max_length=120)
    text: str = Field(default="", max_length=5000)
    message_type: str = Field(default="text", max_length=50)
    payload: dict[str, Any] = Field(default_factory=dict)


class CollabShareNoteRequest(BaseModel):
    user_email: str = Field(min_length=3, max_length=180)
    user_name: str = Field(min_length=1, max_length=120)
    topic: str = Field(min_length=1, max_length=240)
    content: str = Field(min_length=1, max_length=12000)


class CollabShareWorksheetRequest(BaseModel):
    user_email: str = Field(min_length=3, max_length=180)
    user_name: str = Field(min_length=1, max_length=120)
    title: str = Field(min_length=1, max_length=240)
    subject: str = Field(min_length=1, max_length=120)
    topic: str = Field(min_length=1, max_length=120)
    questions: list[str] = Field(default_factory=list)


class CollabMeetRequest(BaseModel):
    user_email: str = Field(min_length=3, max_length=180)
    user_name: str = Field(min_length=1, max_length=120)
    meet_link: str = Field(default="", max_length=500)


load_dotenv()
app = FastAPI(title="School Assistant API", version="1.0.0")

COLLAB_LOCK = threading.Lock()
COLLAB_USERS: dict[str, dict[str, str]] = {}
COLLAB_ROOMS: dict[str, dict[str, Any]] = {}
COLLAB_MESSAGE_TTL_SECONDS = int(os.getenv("COLLAB_MESSAGE_TTL_SECONDS", str(24 * 60 * 60)))
COLLAB_CLEANUP_INTERVAL_SECONDS = int(os.getenv("COLLAB_CLEANUP_INTERVAL_SECONDS", "60"))
COLLAB_MAX_MESSAGES_PER_ROOM = int(os.getenv("COLLAB_MAX_MESSAGES_PER_ROOM", "600"))
COLLAB_LAST_CLEANUP_TS = 0

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@lru_cache(maxsize=1)
def get_embeddings() -> OpenAIEmbeddings:
    return OpenAIEmbeddings(model=EMBEDDING_MODEL)


@lru_cache(maxsize=1)
def get_vector_store() -> FAISS:
    if not VECTORSTORE_INDEX_PATH.exists():
        raise FileNotFoundError(
            f"FAISS index not found at {VECTORSTORE_INDEX_PATH}. Build or download vectorstore first."
        )

    return FAISS.load_local(
        str(VECTORSTORE_DIR),
        get_embeddings(),
        allow_dangerous_deserialization=True,
    )


def ensure_local_vectorstore() -> None:
    if VECTORSTORE_INDEX_PATH.exists():
        return

    zip_url = os.getenv("VECTORSTORE_ZIP_URL", "").strip()
    if not zip_url:
        return

    with tempfile.NamedTemporaryFile(suffix=".zip", delete=False) as tmp_file:
        tmp_path = Path(tmp_file.name)

    try:
        urllib.request.urlretrieve(zip_url, tmp_path)
        target_dir = Path("vectorstore")
        target_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(tmp_path, "r") as zip_ref:
            zip_ref.extractall(target_dir)

        # Support zip files that contain `vectorstore/faiss_index/...`.
        if not VECTORSTORE_INDEX_PATH.exists():
            nested_dir = target_dir / "vectorstore" / "faiss_index"
            nested_index = nested_dir / "index.faiss"
            if nested_index.exists():
                VECTORSTORE_DIR.mkdir(parents=True, exist_ok=True)
                nested_index.replace(VECTORSTORE_DIR / "index.faiss")
                nested_pkl = nested_dir / "index.pkl"
                if nested_pkl.exists():
                    nested_pkl.replace(VECTORSTORE_DIR / "index.pkl")
    finally:
        if tmp_path.exists():
            tmp_path.unlink(missing_ok=True)


def make_math_readable(text: str) -> str:
    """Format math and ensure markdown compatibility."""
    if not text:
        return text

    # Keep basic markdown formatting but make inline math readable
    # Convert LaTeX delimiters to simpler format for mobile display
    text = text.replace("\\[", "\n\n**Equation:**\n```\n").replace("\\]", "\n```\n\n")
    text = text.replace("\\(", "`").replace("\\)", "`")
    
    # Simplify common LaTeX commands for readability
    text = re.sub(r"\\sqrt\{([^}]*)\}", r"√(\1)", text)
    text = re.sub(r"\\frac\{([^}]*)\}\{([^}]*)\}", r"(\1)/(\2)", text)
    
    # Replace Greek letters with Unicode symbols
    replacements = {
        "\\theta": "θ",
        "\\alpha": "α",
        "\\beta": "β",
        "\\gamma": "γ",
        "\\Delta": "Δ",
        "\\delta": "δ",
        "\\pi": "π",
        "\\mu": "μ",
        "\\sigma": "σ",
        "\\omega": "ω",
        "\\Omega": "Ω",
        "\\lambda": "λ",
        "\\times": "×",
        "\\cdot": "·",
        "\\pm": "±",
        "\\approx": "≈",
        "\\leq": "≤",
        "\\geq": "≥",
        "\\neq": "≠",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)

    return text.strip()


def is_textbook_only_mode(question: str) -> bool:
    lowered = question.lower()
    triggers = [
        "only from",
        "from textbook only",
        "from materials only",
        "strictly from",
        "only from provided",
        "only from pdf",
        "from notes only",
        "ncert only",
    ]
    return any(trigger in lowered for trigger in triggers)


def _keyword_set(text: str) -> set[str]:
    stopwords = {
        "the", "is", "are", "a", "an", "of", "to", "for", "and", "or", "in", "on", "at",
        "with", "how", "what", "why", "when", "which", "explain", "define", "find", "derive",
        "class", "chapter", "question", "from", "only", "pdf", "notes", "give", "write",
    }
    words = re.findall(r"[a-zA-Z0-9_]+", text.lower())
    return {w for w in words if len(w) > 2 and w not in stopwords}


def _rank_docs_by_question(question: str, docs_with_scores: list[tuple[Any, float]]) -> list[Any]:
    q_words = _keyword_set(question)
    ranked: list[tuple[int, float, Any]] = []
    for doc, distance in docs_with_scores:
        content = getattr(doc, "page_content", "") or ""
        overlap = len(q_words.intersection(_keyword_set(content)))
        ranked.append((overlap, float(distance), doc))

    # Prefer high keyword overlap first, then better vector similarity (lower distance).
    ranked.sort(key=lambda item: (-item[0], item[1]))
    return [doc for _, _, doc in ranked]


def get_retrieved_context(question: str) -> tuple[str, int]:
    vector_store = get_vector_store()
    docs_with_scores = vector_store.similarity_search_with_score(
        question,
        k=max(RETRIEVAL_CANDIDATE_K, RETRIEVAL_FINAL_K),
    )

    if not docs_with_scores:
        return "", 0

    ranked_docs = _rank_docs_by_question(question, docs_with_scores)
    docs = ranked_docs[:RETRIEVAL_FINAL_K]

    if not docs:
        return "", 0

    context_parts: list[str] = []
    for index, doc in enumerate(docs, start=1):
        meta = getattr(doc, "metadata", {}) or {}
        source = Path(str(meta.get("source", f"chunk-{index}"))).name
        snippet = (getattr(doc, "page_content", "") or "")[:RETRIEVAL_CHARS_PER_CHUNK]
        # Don't include source labels in context to avoid them appearing in output
        context_parts.append(snippet)

    return "\n\n".join(context_parts), len(docs)


def strip_source_citations(text: str) -> str:
    """Remove source citations like [Source 1], [Source 2], etc. from text."""
    return re.sub(r"\[Source\s+\d+\]", "", text).strip()


def build_conversation_messages(history: list[dict[str, str]], system_prompt: str, user_message: str) -> list:
    """Build a list of messages for the LLM from conversation history."""
    messages = [SystemMessage(content=system_prompt)]
    
    # Add conversation history
    for msg in history:
        role = msg.get("role", "")
        content = msg.get("content", "")
        if role == "user":
            messages.append(HumanMessage(content=content))
        elif role == "assistant":
            messages.append(AIMessage(content=content))
    
    # Add current question
    messages.append(HumanMessage(content=user_message))
    return messages


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _now_ts() -> int:
    return int(datetime.now(timezone.utc).timestamp())


def _sanitize_email(value: str) -> str:
    return value.strip().lower()


def _room_public_payload(room: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": room["id"],
        "name": room["name"],
        "owner_email": room["owner_email"],
        "owner_name": room["owner_name"],
        "is_public": room["is_public"],
        "created_at": room["created_at"],
        "member_count": len(room["members"]),
        "members": room["members"],
        "meet_link": room.get("meet_link", ""),
    }


def _assert_member(room: dict[str, Any], user_email: str) -> None:
    member_emails = room.get("member_emails")
    if not isinstance(member_emails, set):
        member_emails = {
            _sanitize_email(m.get("email", ""))
            for m in room.get("members", [])
            if m.get("email", "")
        }
        room["member_emails"] = member_emails
    if user_email not in member_emails:
        raise HTTPException(status_code=403, detail="Join this collab room first.")


def _message_ts(message: dict[str, Any]) -> int:
    raw_ts = message.get("created_at_ts")
    if isinstance(raw_ts, int):
        return raw_ts

    raw_iso = str(message.get("created_at", ""))
    if raw_iso.endswith("Z"):
        raw_iso = raw_iso.replace("Z", "+00:00")
    try:
        return int(datetime.fromisoformat(raw_iso).timestamp())
    except ValueError:
        return 0


def _cleanup_collab_state_if_due() -> None:
    global COLLAB_LAST_CLEANUP_TS
    now_ts = _now_ts()
    if now_ts - COLLAB_LAST_CLEANUP_TS < COLLAB_CLEANUP_INTERVAL_SECONDS:
        return

    cutoff_ts = now_ts - COLLAB_MESSAGE_TTL_SECONDS
    for room in COLLAB_ROOMS.values():
        messages = room.get("messages", [])
        if not messages:
            continue
        room["messages"] = [m for m in messages if _message_ts(m) >= cutoff_ts]

    COLLAB_LAST_CLEANUP_TS = now_ts


def _add_room_message(
    room: dict[str, Any],
    user_email: str,
    user_name: str,
    message_type: str,
    text: str,
    payload: dict[str, Any] | None = None,
) -> dict[str, Any]:
    now_ts = _now_ts()
    message = {
        "id": str(uuid4()),
        "sender_email": user_email,
        "sender_name": user_name,
        "message_type": message_type,
        "text": text,
        "payload": payload or {},
        "created_at": _now_iso(),
        "created_at_ts": now_ts,
    }
    room["messages"].append(message)
    if len(room["messages"]) > COLLAB_MAX_MESSAGES_PER_ROOM:
        room["messages"] = room["messages"][-COLLAB_MAX_MESSAGES_PER_ROOM:]
    return message


def answer_question(question: str, history: list[dict[str, str]] | None = None) -> ChatResponse:
    if history is None:
        history = []
    
    context, chunk_count = get_retrieved_context(question)
    used_context = bool(context.strip())
    strict_mode = is_textbook_only_mode(question)

    if strict_mode and not used_context:
        return ChatResponse(
            answer="The provided materials do not contain information relevant to this question.",
            used_context=False,
            context_chunks=0,
        )

    system_prompt = (
        "You are an expert Class 11-12 chemistry and physics tutor grounded in retrieved study materials.\n"
        "CRITICAL: Always read the entire conversation history to understand what 'this', 'that', 'these topics', 'it', etc. refer to.\n"
        "When a user says 'make a worksheet on these topics' or 'explain that', look at the previous messages to understand the context.\n"
        "\n"
        "**FORMATTING REQUIREMENTS:**\n"
        "- Use Markdown formatting for better readability\n"
        "- Use ## for main headings, ### for subheadings\n"
        "- Use **bold** for important terms\n"
        "- Use tables for comparisons (| Column 1 | Column 2 |\n|---------|---------|\n| data | data |)\n"
        "- Use bullet points (- item) or numbered lists (1. item) for steps\n"
        "- Use inline code `like this` for formulas and chemical symbols\n"
        "- Use > for important notes or key points\n"
        "- For equations, use readable format: F = ma, E = mc², PV = nRT, etc.\n"
        "- Use Unicode symbols: θ α β γ Δ π × · ± ≈ √\n"
        "\n"
        "Always prioritize retrieved context over model memory.\n"
        "When retrieved context is sufficient, answer strictly from it.\n"
        "If context is incomplete and strict textbook mode is NOT requested, complete with careful domain knowledge.\n"
        "If strict textbook mode is requested, do not add outside facts.\n"
        "Prefer concise, exam-ready answers with steps and key points.\n\n"
        f"Retrieved Context:\n{context if used_context else 'No relevant context retrieved.'}\n\n"
        f"Strict textbook mode: {'yes' if strict_mode else 'no'}"
    )

    messages = build_conversation_messages(history, system_prompt, question)

    llm = ChatOpenAI(model_name=CHAT_MODEL, temperature=0)
    result = llm.invoke(messages)

    answer = make_math_readable(str(result.content).strip())
    answer = strip_source_citations(answer)

    return ChatResponse(
        answer=answer,
        used_context=used_context,
        context_chunks=chunk_count,
    )


def answer_question_with_image(question: str, image_base64: str, mime_type: str, history: list[dict[str, str]] | None = None) -> ChatResponse:
    if history is None:
        history = []
    
    context, chunk_count = get_retrieved_context(question)
    used_context = bool(context.strip())
    strict_mode = is_textbook_only_mode(question)

    if strict_mode and not used_context:
        return ChatResponse(
            answer="The provided materials do not contain information relevant to this question.",
            used_context=False,
            context_chunks=0,
        )

    prompt_text = (
        "You are an expert chemistry and physics tutor. Analyze the attached image and answer the question.\n"
        "CRITICAL: Read the conversation history below to understand what 'this', 'that', 'these', 'it' refer to in the question.\n"
        "\n"
        "**FORMATTING REQUIREMENTS:**\n"
        "- Use Markdown formatting for better readability\n"
        "- Use ## for main headings, ### for subheadings\n"
        "- Use **bold** for important terms\n"
        "- Use tables for comparisons\n"
        "- Use bullet points or numbered lists for steps\n"
        "- Use inline code `like this` for formulas\n"
        "- For equations, use readable format with Unicode symbols: F = ma, E = mc², PV = nRT\n"
        "- Use symbols: θ α β γ Δ π × · ± ≈ √\n"
        "\n"
        "Use retrieved context first where applicable.\n"
        "If image + context are insufficient and strict textbook mode is NOT requested, complete with careful domain knowledge.\n"
        "If strict textbook mode is requested, do not add outside facts.\n"
        "Interpret formulas/graphs/diagrams clearly.\n\n"
        f"Retrieved context:\n{context if used_context else 'No additional context retrieved.'}\n\n"
        f"Strict textbook mode: {'yes' if strict_mode else 'no'}\n"
    )
    
  
    if history:
        prompt_text += "\nConversation history:\n"
        for msg in history[-6:]:  # Last 6 messages for context
            role = msg.get("role", "")
            content = msg.get("content", "")[:300]  # Truncate for brevity
            prompt_text += f"{role}: {content}\n"
        prompt_text += "\n"
    
    prompt_text += f"Current question: {question}"

    # Validate base64 early to return clean client error for malformed payloads.
    base64.b64decode(image_base64, validate=True)

    vision_llm = ChatOpenAI(model_name=VISION_CHAT_MODEL, temperature=0)
    ai_message = vision_llm.invoke(
        [
            HumanMessage(
                content=[
                    {"type": "text", "text": prompt_text},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime_type};base64,{image_base64}"},
                    },
                ]
            )
        ]
    )

    answer = make_math_readable(str(ai_message.content).strip())
    answer = strip_source_citations(answer)

    return ChatResponse(
        answer=answer,
        used_context=used_context,
        context_chunks=chunk_count,
    )


def _extract_pdf_text(attachment: NoteAttachment) -> str:
    data = base64.b64decode(attachment.base64_data, validate=True)
    reader = PdfReader(io.BytesIO(data))
    chunks: list[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        if text.strip():
            chunks.append(text.strip())

    content = "\n\n".join(chunks).strip()
    if not content:
        return ""
    return content[:7000]


def _extract_image_text(attachment: NoteAttachment, topic: str) -> str:
    base64.b64decode(attachment.base64_data, validate=True)

    vision_llm = ChatOpenAI(model_name=VISION_CHAT_MODEL, temperature=0)
    ai_message = vision_llm.invoke(
        [
            HumanMessage(
                content=[
                    {
                        "type": "text",
                        "text": (
                            "You are extracting study points from an image for school notes. "
                            f"Topic: {topic}. "
                            "Return concise bullet points of key concepts, definitions, formulas, and examples visible in the image."
                        ),
                    },
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:{attachment.mime_type};base64,{attachment.base64_data}"
                        },
                    },
                ]
            )
        ]
    )

    text = str(ai_message.content).strip()
    return text[:3500]


def generate_notes(
    topic: str,
    details: str,
    attachments: list[NoteAttachment],
) -> NotesGenerationResponse:
    extracted_sections: list[str] = []

    for attachment in attachments:
        mime = attachment.mime_type.lower().strip()
        name = attachment.name.strip()
        section_text = ""

        if "pdf" in mime or name.lower().endswith(".pdf"):
            section_text = _extract_pdf_text(attachment)
        elif mime.startswith("image/"):
            section_text = _extract_image_text(attachment, topic)
        else:
            continue

        if section_text.strip():
            extracted_sections.append(
                f"Source: {name}\n{section_text.strip()}"
            )

    context_blocks: list[str] = []
    if details.strip():
        context_blocks.append(f"User details:\n{details.strip()}")
    if extracted_sections:
        context_blocks.append("Extracted content from files/images:\n" + "\n\n".join(extracted_sections))

    context_text = "\n\n".join(context_blocks) if context_blocks else "No extra context provided."

    llm = ChatOpenAI(model_name=CHAT_MODEL, temperature=0)
    prompt = (
        "You are a school note generator. Write clear, exam-ready notes in markdown.\n"
        "Formatting rules:\n"
        "- Use markdown headings and subheadings.\n"
        "- Use bullet lists for key points and numbered steps where needed.\n"
        "- Include at least one markdown table when comparison/summary helps.\n"
        "- Preserve math/science symbols and signs (e.g., +/- <= >= != theta alpha beta delta pi mu sigma omega sqrt).\n"
        "- Use clean Unicode symbols where useful (x, dot, +- , ~=, <=, >=, !=, theta, alpha, beta, delta, pi, mu, sigma, omega, sqrt).\n"
        "- Add light, relevant emojis for section labels (example: Overview, Key Points, Formulas, Quick Revision).\n"
        "- Keep spacing readable and output polished for direct study use.\n"
        "Structure output with: Overview, Key Concepts, Important Points, Formula/Examples (if relevant), and Quick Revision Checklist.\n"
        "Keep it concise but complete for revision.\n\n"
        f"Topic: {topic.strip()}\n\n"
        f"Context:\n{context_text}"
    )

    result = llm.invoke([HumanMessage(content=prompt)])
    note = make_math_readable(str(result.content).strip())

    return NotesGenerationResponse(
        note=note,
        attachments_processed=len(extracted_sections),
    )


@app.get("/health")
def health_check() -> dict:
    key_present = bool(os.getenv("OPENAI_API_KEY", "").strip())
    vector_ready = VECTORSTORE_INDEX_PATH.exists()
    return {
        "status": "ok",
        "openai_key_present": key_present,
        "vector_index_path": str(VECTORSTORE_INDEX_PATH),
        "vector_ready": vector_ready,
    }


@app.post("/chat", response_model=ChatResponse)
def chat(payload: ChatRequest) -> ChatResponse:
    try:
        return answer_question(payload.question.strip(), history=payload.history)
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Chat failed: {exc}") from exc


@app.post("/chat/image", response_model=ChatResponse)
def chat_with_image(payload: ImageChatRequest) -> ChatResponse:
    try:
        return answer_question_with_image(
            question=payload.question.strip(),
            image_base64=payload.image_base64.strip(),
            mime_type=payload.mime_type.strip() or "image/jpeg",
            history=payload.history,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid image payload: {exc}") from exc
    except FileNotFoundError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Image chat failed: {exc}") from exc


@app.post("/notes/generate", response_model=NotesGenerationResponse)
def notes_generate(payload: NotesGenerationRequest) -> NotesGenerationResponse:
    try:
        return generate_notes(
            topic=payload.topic,
            details=payload.details,
            attachments=payload.attachments,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid attachment payload: {exc}") from exc
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Notes generation failed: {exc}") from exc


@app.post("/collab/auth/google", response_model=GoogleAuthResponse)
def collab_google_auth(payload: GoogleAuthRequest) -> GoogleAuthResponse:
    email = _sanitize_email(payload.email)
    name = payload.name.strip()
    if not email or "@" not in email:
        raise HTTPException(status_code=400, detail="Invalid Google account email.")

    # MVP behavior: trust GoogleSignIn result from client and keep an in-memory identity map.
    # For production, verify payload.id_token server-side with Google token verification.
    user_id = email
    with COLLAB_LOCK:
        COLLAB_USERS[user_id] = {
            "user_id": user_id,
            "email": email,
            "name": name,
        }

    return GoogleAuthResponse(user_id=user_id, email=email, name=name)


@app.post("/collab/auth/basic", response_model=GoogleAuthResponse)
def collab_basic_auth(payload: BasicAuthRequest) -> GoogleAuthResponse:
    name = payload.name.strip()
    if not name:
        raise HTTPException(status_code=400, detail="Name is required.")

    email = _sanitize_email(payload.email)
    if not email:
        guest_key = re.sub(r"[^a-z0-9]+", "", name.lower())[:24] or "guest"
        email = f"{guest_key}_{str(uuid4())[:8]}@guest.local"

    if "@" not in email:
        raise HTTPException(status_code=400, detail="Invalid email format.")

    user_id = email
    with COLLAB_LOCK:
        COLLAB_USERS[user_id] = {
            "user_id": user_id,
            "email": email,
            "name": name,
        }

    return GoogleAuthResponse(user_id=user_id, email=email, name=name)


@app.post("/collab/rooms")
def collab_create_room(payload: CollabCreateRoomRequest) -> dict[str, Any]:
    creator_email = _sanitize_email(payload.creator_email)
    room_id = str(uuid4())[:8]
    created_ts = _now_ts()
    room = {
        "id": room_id,
        "name": payload.name.strip(),
        "owner_email": creator_email,
        "owner_name": payload.creator_name.strip(),
        "is_public": payload.is_public,
        "created_at": _now_iso(),
        "created_at_ts": created_ts,
        "members": [
            {
                "email": creator_email,
                "name": payload.creator_name.strip(),
            }
        ],
        "member_emails": {creator_email},
        "messages": [],
        "meet_link": "",
    }

    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        COLLAB_ROOMS[room_id] = room
        _add_room_message(
            room,
            creator_email,
            payload.creator_name.strip(),
            "system",
            f"{payload.creator_name.strip()} created this collab room.",
        )

    return {"room": _room_public_payload(room)}


@app.get("/collab/rooms")
def collab_list_rooms(user_email: str = "") -> dict[str, Any]:
    email = _sanitize_email(user_email)
    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        rooms = []
        for room in COLLAB_ROOMS.values():
            member_emails = room.get("member_emails")
            if not isinstance(member_emails, set):
                member_emails = {
                    _sanitize_email(m.get("email", ""))
                    for m in room.get("members", [])
                    if m.get("email", "")
                }
                room["member_emails"] = member_emails
            if room["is_public"] or (email and email in member_emails):
                rooms.append(_room_public_payload(room))

    rooms.sort(key=lambda r: r.get("created_at", ""), reverse=True)
    return {"rooms": rooms}


@app.post("/collab/rooms/{room_id}/join")
def collab_join_room(room_id: str, payload: CollabJoinRoomRequest) -> dict[str, Any]:
    user_email = _sanitize_email(payload.user_email)
    user_name = payload.user_name.strip()

    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")

        existing = next(
            (m for m in room["members"] if _sanitize_email(m.get("email", "")) == user_email),
            None,
        )
        if existing is None:
            room["members"].append({"email": user_email, "name": user_name})
            room.setdefault("member_emails", set()).add(user_email)
            _add_room_message(
                room,
                user_email,
                user_name,
                "system",
                f"{user_name} joined the collab.",
            )

    return {"room": _room_public_payload(room)}


@app.get("/collab/rooms/{room_id}")
def collab_get_room(room_id: str, user_email: str = "") -> dict[str, Any]:
    email = _sanitize_email(user_email)
    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")

        if not room["is_public"]:
            _assert_member(room, email)

        return {
            "room": _room_public_payload(room),
            "messages": room["messages"][-100:],
        }


@app.get("/collab/rooms/{room_id}/messages")
def collab_get_messages(room_id: str, user_email: str = "") -> dict[str, Any]:
    email = _sanitize_email(user_email)
    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")

        if not room["is_public"]:
            _assert_member(room, email)

        return {"messages": room["messages"][-250:]}


@app.post("/collab/rooms/{room_id}/messages")
def collab_send_message(room_id: str, payload: CollabMessageRequest) -> dict[str, Any]:
    user_email = _sanitize_email(payload.user_email)
    user_name = payload.user_name.strip()
    text = payload.text.strip()
    if payload.message_type == "text" and not text:
        raise HTTPException(status_code=400, detail="Message cannot be empty.")

    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")
        _assert_member(room, user_email)

        message = _add_room_message(
            room,
            user_email,
            user_name,
            payload.message_type,
            text,
            payload.payload,
        )

    return {"message": message}


@app.post("/collab/rooms/{room_id}/share-note")
def collab_share_note(room_id: str, payload: CollabShareNoteRequest) -> dict[str, Any]:
    user_email = _sanitize_email(payload.user_email)
    user_name = payload.user_name.strip()

    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")
        _assert_member(room, user_email)

        message = _add_room_message(
            room,
            user_email,
            user_name,
            "note",
            f"Shared note: {payload.topic.strip()}",
            {
                "topic": payload.topic.strip(),
                "content": payload.content.strip(),
            },
        )

    return {"message": message}


@app.post("/collab/rooms/{room_id}/share-worksheet")
def collab_share_worksheet(room_id: str, payload: CollabShareWorksheetRequest) -> dict[str, Any]:
    user_email = _sanitize_email(payload.user_email)
    user_name = payload.user_name.strip()
    questions = [q.strip() for q in payload.questions if q.strip()]
    if not questions:
        raise HTTPException(status_code=400, detail="Worksheet has no questions.")

    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")
        _assert_member(room, user_email)

        message = _add_room_message(
            room,
            user_email,
            user_name,
            "worksheet",
            f"Shared worksheet: {payload.title.strip()}",
            {
                "title": payload.title.strip(),
                "subject": payload.subject.strip(),
                "topic": payload.topic.strip(),
                "questions": questions,
            },
        )

    return {"message": message}


@app.post("/collab/rooms/{room_id}/meet")
def collab_create_or_update_meet(room_id: str, payload: CollabMeetRequest) -> dict[str, Any]:
    user_email = _sanitize_email(payload.user_email)
    user_name = payload.user_name.strip()
    link = payload.meet_link.strip() or "https://meet.google.com/new"

    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")
        _assert_member(room, user_email)

        room["meet_link"] = link
        message = _add_room_message(
            room,
            user_email,
            user_name,
            "meet",
            f"Updated Google Meet link for this collab.",
            {"meet_link": link},
        )

    return {"room": _room_public_payload(room), "message": message}


@app.on_event("startup")
def startup_event() -> None:
    ensure_local_vectorstore()
