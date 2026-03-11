import os
import base64
import re
import tempfile
import urllib.request
import zipfile
from functools import lru_cache
from pathlib import Path
from typing import Any

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from langchain_community.vectorstores import FAISS
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from pydantic import BaseModel, Field

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


load_dotenv()
app = FastAPI(title="School Assistant API", version="1.0.0")

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
    if not text:
        return text

    text = text.replace("\\[", "").replace("\\]", "")
    text = text.replace("\\(", "").replace("\\)", "")

    text = re.sub(r"\\\\sqrt\{([^}]*)\}", r"sqrt(\1)", text)
    text = re.sub(r"\\\\frac\{([^}]*)\}\{([^}]*)\}", r"(\1)/(\2)", text)
    text = re.sub(r"\\\\mathbf\{([^}]*)\}", r"\1", text)
    text = re.sub(r"\\\\text\{([^}]*)\}", r"\1", text)

    replacements = {
        "\\theta": "theta",
        "\\alpha": "alpha",
        "\\beta": "beta",
        "\\gamma": "gamma",
        "\\Delta": "Delta",
        "\\times": "x",
        "\\cdot": "*",
        "\\cos": "cos",
        "\\sin": "sin",
        "\\tan": "tan",
        "\\pi": "pi",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)

    return text.replace("\\", "").strip()


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
        "Always prioritize retrieved context over model memory.\n"
        "When retrieved context is sufficient, answer strictly from it.\n"
        "If context is incomplete and strict textbook mode is NOT requested, complete with careful domain knowledge.\n"
        "If strict textbook mode is requested, do not add outside facts.\n"
        "When formulas are needed, write equations in plain text only (no LaTeX).\n"
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
        "Use retrieved context first where applicable.\n"
        "If image + context are insufficient and strict textbook mode is NOT requested, complete with careful domain knowledge.\n"
        "If strict textbook mode is requested, do not add outside facts.\n"
        "Interpret formulas/graphs/diagrams clearly.\n"
        "Write equations in plain text only (example: R = sqrt(A^2 + B^2 + 2AB cos(theta))). Do not use LaTeX.\n\n"
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


@app.on_event("startup")
def startup_event() -> None:
    ensure_local_vectorstore()
