import base64
import io
import os
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
CHAT_MODEL = os.getenv("CHAT_MODEL", "gpt-5-mini")  # Balanced cost + quality
NOTES_MODEL = os.getenv("NOTES_MODEL", "gpt-5-mini")  # Use same model for notes for consistency
VISION_CHAT_MODEL = os.getenv("VISION_CHAT_MODEL", "gpt-4.1-mini")
VECTORSTORE_DIR = Path("vectorstore/faiss_index")
VECTORSTORE_INDEX_PATH = VECTORSTORE_DIR / "index.faiss"

# Retrieval sizing controls how much context is fed into the model.
# Larger values improve quality but increase token cost.
RETRIEVAL_CANDIDATE_K = int(os.getenv("RETRIEVAL_CANDIDATE_K", "10"))
RETRIEVAL_FINAL_K = int(os.getenv("RETRIEVAL_FINAL_K", "5"))
RETRIEVAL_CHARS_PER_CHUNK = int(os.getenv("RETRIEVAL_CHARS_PER_CHUNK", "700"))
RETRIEVAL_MAX_CONTEXT_CHARS = int(os.getenv("RETRIEVAL_MAX_CONTEXT_CHARS", "2800"))

# Conversation history limits
MAX_HISTORY_MESSAGES = int(os.getenv("MAX_HISTORY_MESSAGES", "3"))
MAX_HISTORY_CHARS_PER_MESSAGE = int(os.getenv("MAX_HISTORY_CHARS_PER_MESSAGE", "500"))

# Token limits (keep moderate to avoid high cost)
CHAT_MAX_TOKENS = int(os.getenv("CHAT_MAX_TOKENS", "1200"))
NOTES_MAX_TOKENS = int(os.getenv("NOTES_MAX_TOKENS", "1000"))
VISION_CHAT_MAX_TOKENS = int(os.getenv("VISION_CHAT_MAX_TOKENS", "900"))

# Notes context shaping controls attachment-heavy token growth.
NOTES_MAX_DETAILS_CHARS = int(os.getenv("NOTES_MAX_DETAILS_CHARS", "1800"))
NOTES_MAX_ATTACHMENT_CHARS_PER_FILE = int(os.getenv("NOTES_MAX_ATTACHMENT_CHARS_PER_FILE", "2500"))
NOTES_MAX_TOTAL_ATTACHMENT_CHARS = int(os.getenv("NOTES_MAX_TOTAL_ATTACHMENT_CHARS", "8000"))


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
    attachments: list[NoteAttachment] = Field(default_factory=list)


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


class CollabRemoveMemberRequest(BaseModel):
    owner_email: str = Field(min_length=3, max_length=180)
    member_email: str = Field(min_length=3, max_length=180)


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
    """Convert LaTeX math to plain readable text. Priority: remove all backslashes and make readable."""
    if not text:
        return text

    # Remove LaTeX delimiters (keep content).
    text = re.sub(r"\\\[|\\\]|\$\$|\\\(|\\\)", "", text)

    # Replace Greek letters and math symbols with Unicode FIRST, before stripping backslashes.
    replacements = {
        "\\epsilon": "ε",
        "\\varepsilon": "ε",
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
        "\\phi": "φ",
        "\\psi": "ψ",
        "\\xi": "ξ",
        "\\zeta": "ζ",
        "\\eta": "η",
        "\\tau": "τ",
        "\\rho": "ρ",
        "\\times": "×",
        "\\cdot": "·",
        "\\pm": "±",
        "\\mp": "∓",
        "\\approx": "≈",
        "\\leq": "≤",
        "\\geq": "≥",
        "\\neq": "≠",
        "\\equiv": "≡",
        "\\propto": "∝",
        "\\sum": "∑",
        "\\prod": "∏",
        "\\int": "∫",
        "\\partial": "∂",
        "\\nabla": "∇",
        "\\infty": "∞",
        "\\rightarrow": "→",
        "\\leftarrow": "←",
        "\\leftrightarrow": "↔",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)

    # Simplify LaTeX fraction, sqrt, etc.
    text = re.sub(r"\\sqrt\{([^}]*)\}", r"sqrt(\1)", text)
    text = re.sub(r"\\frac\{([^}]*)\}\{([^}]*)\}", r"(\1)/(\2)", text)
    text = re.sub(r"\\mathrm\{([^}]*)\}", r"\1", text)
    text = re.sub(r"\\text\{([^}]*)\}", r"\1", text)
    text = re.sub(r"\\operatorname\{([^}]*)\}", r"\1", text)
    
    # Remove \left and \right
    text = text.replace("\\left", "").replace("\\right", "")

    # Strip ALL remaining backslashes before any character (removes stray LaTeX commands).
    text = re.sub(r"\\([a-zA-Z]+|\W)", r"\1", text)

    # Remove all curly braces (they're just LaTeX grouping).
    text = text.replace("{", "").replace("}", "")

    # Convert subscript 0/1/2/3 to Unicode subscripts.
    text = re.sub(r"([a-zA-Zα-ωΔΩε∂∇])_0\b", r"\1₀", text)
    text = re.sub(r"([a-zA-Zα-ωΔΩε∂∇])_1\b", r"\1₁", text)
    text = re.sub(r"([a-zA-Zα-ωΔΩε∂∇])_2\b", r"\1₂", text)
    text = re.sub(r"([a-zA-Zα-ωΔΩε∂∇])_3\b", r"\1₃", text)

    # Fix subscript O (letter) that should be 0 (number).
    text = re.sub(r"_O\b", "₀", text)

    # Common field/charge notation.
    text = re.sub(r"\bE_\+\b", "E₊", text)
    text = re.sub(r"\bE_-\b", "E₋", text)

    # Normalize spaces around key symbols.
    text = re.sub(r"\s*=\s*", " = ", text)
    text = re.sub(r"\s*\+\s*", " + ", text)
    text = re.sub(r"[ ]{2,}", " ", text)
    # Keep paragraph breaks for markdown readability.
    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()


def _finalize_answer_text(text: str) -> str:
    """Normalize markdown/list artifacts so output is readable in the mobile UI."""
    if not text:
        return text

    cleaned = text

    # Remove duplicate bullets like "1. • • ..." or "- • ...".
    cleaned = re.sub(r"(?m)^(\s*\d+\.?)\s*[•\-]+\s*[•\-]+\s*", r"\1 ", cleaned)
    cleaned = re.sub(r"(?m)^\s*[•\-]+\s*[•\-]+\s*", "- ", cleaned)

    # Normalize spacing around numbered items and headings.
    cleaned = re.sub(r"(?m)^\s*(\d+)\s*\)\s*", r"\1. ", cleaned)
    cleaned = re.sub(r"(?m)^\s*(\d+\.)\s+", r"\1 ", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)
    cleaned = re.sub(r"[ \t]{2,}", " ", cleaned)

    return cleaned.strip()


def _finalize_notes_text(text: str) -> str:
    """Apply stricter note formatting so sections are consistently readable in app UI."""
    if not text:
        return text

    cleaned = _finalize_answer_text(text)

    # Normalize common section titles to markdown headings.
    heading_patterns = {
        r"(?im)^\s*overview\s*:?": "## Overview",
        r"(?im)^\s*key\s+concepts?\s*:?": "## Key Concepts",
        r"(?im)^\s*important\s+points?\s*:?": "## Important Points",
        r"(?im)^\s*formulas?\s*/\s*examples?\s*:?": "## Formulas and Examples",
        r"(?im)^\s*formula(?:s)?\s+and\s+examples?\s*:?": "## Formulas and Examples",
        r"(?im)^\s*quick\s+revision\s+checklist\s*:?": "## Quick Revision Checklist",
    }
    for pattern, replacement in heading_patterns.items():
        cleaned = re.sub(pattern, replacement, cleaned)

    # Normalize bullet characters for consistent rendering.
    cleaned = re.sub(r"(?m)^\s*[•●]\s+", "- ", cleaned)
    cleaned = re.sub(r"\n{3,}", "\n\n", cleaned)

    # Ensure minimum structure exists if model skipped headings.
    if "## Overview" not in cleaned:
        cleaned = f"## Overview\n{cleaned}".strip()
    if "## Quick Revision Checklist" not in cleaned:
        cleaned = f"{cleaned}\n\n## Quick Revision Checklist\n- Revise key definitions\n- Revise core formulas\n- Practice one representative question"

    return cleaned.strip()


def _looks_incomplete(text: str) -> bool:
    if not text:
        return True
    tail = text.rstrip()
    if not tail:
        return True
    return tail.endswith((":", ",", "=", "+", "-", "*", "/", "(", "["))


def _extract_finish_reason(result: Any) -> str:
    metadata = getattr(result, "response_metadata", None) or {}
    finish_reason = metadata.get("finish_reason", "")
    if isinstance(finish_reason, list) and finish_reason:
        finish_reason = finish_reason[0]
    return str(finish_reason).strip().lower()


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


def _response_style_instructions(question: str) -> str:
    q = question.strip().lower()
    short_q_prefixes = (
        "what is",
        "define",
        "state",
        "name",
        "who is",
        "when is",
        "where is",
    )

    if q.startswith(short_q_prefixes):
        return (
            "Question type: direct factual question. "
            "Answer in 2-5 lines only. Start with the exact answer, then one short supporting line. "
            "Do not add full-topic explanation unless explicitly asked."
        )

    if any(token in q for token in ("mcq", "option", "choose the correct", "a)", "b)", "c)", "d)")):
        return (
            "Question type: MCQ/objective. "
            "Return only: Correct option + 1-2 line reason."
        )

    if any(token in q for token in ("solve", "calculate", "numerical", "find", "evaluate")):
        return (
            "Question type: numerical/problem solving. "
            "Return this exact order: Given, Formula, Substitution, Final Answer. "
            "Ensure the final numeric expression/result is explicitly written as the last line."
        )

    if any(token in q for token in ("difference", "compare", "vs", "distinguish")):
        return (
            "Question type: comparison. "
            "Prefer a short markdown table with only the key differences."
        )

    if any(token in q for token in ("explain", "why", "how", "derive", "in detail", "detailed")):
        return (
            "Question type: derivation/explanatory. "
            "Use this exact structure: "
            "1) Setup and symbols, "
            "2) Governing law/formula, "
            "3) Substitution and simplification in clear numbered steps, "
            "4) Final derived expression with condition/approximation used. "
            "Do not switch to a different physical system than asked in the question. "
            "If setup is ambiguous, state one-line assumption first. "
            "Do not leave derivation incomplete."
        )

    return (
        "Question type: standard query. "
        "Answer directly and briefly first (3-6 lines), then add only essential supporting points."
    )


def _is_short_direct_question(question: str) -> bool:
    q = question.strip().lower()
    prefixes = (
        "what is",
        "define",
        "state",
        "name",
        "who is",
        "when is",
        "where is",
    )
    return len(q) <= 120 or q.startswith(prefixes)


def _is_complex_question(question: str) -> bool:
    q = question.strip().lower()
    complex_signals = (
        "derive",
        "derivation",
        "prove",
        "numerical",
        "calculate",
        "multi-step",
        "in detail",
        "mechanism",
        "reaction pathway",
        "explain why",
        "compare and contrast",
    )
    return len(q) > 180 or any(token in q for token in complex_signals)


def _adaptive_chat_budget(question: str) -> dict[str, int]:
    if _is_complex_question(question):
        return {
            "candidate_k": max(RETRIEVAL_CANDIDATE_K, 10),
            "final_k": max(RETRIEVAL_FINAL_K, 5),
            "chars_per_chunk": max(RETRIEVAL_CHARS_PER_CHUNK, 700),
            "max_context_chars": max(RETRIEVAL_MAX_CONTEXT_CHARS, 2800),
            "max_tokens": CHAT_MAX_TOKENS,
            "history_messages": max(MAX_HISTORY_MESSAGES, 3),
        }

    if _is_short_direct_question(question):
        return {
            "candidate_k": min(RETRIEVAL_CANDIDATE_K, 6),
            "final_k": min(RETRIEVAL_FINAL_K, 3),
            "chars_per_chunk": min(RETRIEVAL_CHARS_PER_CHUNK, 420),
            "max_context_chars": min(RETRIEVAL_MAX_CONTEXT_CHARS, 1300),
            "max_tokens": min(CHAT_MAX_TOKENS, 420),
            "history_messages": min(MAX_HISTORY_MESSAGES, 2),
        }

    return {
        "candidate_k": min(max(RETRIEVAL_CANDIDATE_K, 8), 10),
        "final_k": min(max(RETRIEVAL_FINAL_K, 4), 5),
        "chars_per_chunk": min(max(RETRIEVAL_CHARS_PER_CHUNK, 550), 700),
        "max_context_chars": min(max(RETRIEVAL_MAX_CONTEXT_CHARS, 2000), 2600),
        "max_tokens": min(max(CHAT_MAX_TOKENS, 700), 900),
        "history_messages": min(max(MAX_HISTORY_MESSAGES, 2), 3),
    }


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


def get_retrieved_context(
    question: str,
    *,
    candidate_k: int,
    final_k: int,
    chars_per_chunk: int,
    max_context_chars: int,
) -> tuple[str, int]:
    vector_store = get_vector_store()
    docs_with_scores = vector_store.similarity_search_with_score(
        question,
        k=max(candidate_k, final_k),
    )

    if not docs_with_scores:
        return "", 0

    ranked_docs = _rank_docs_by_question(question, docs_with_scores)
    docs = ranked_docs[:final_k]

    if not docs:
        return "", 0

    context_parts: list[str] = []
    total_chars = 0
    for doc in docs:
        snippet = (getattr(doc, "page_content", "") or "")[:chars_per_chunk]
        snippet = snippet.strip()
        if not snippet:
            continue

        remaining_chars = max_context_chars - total_chars
        if remaining_chars <= 0:
            break

        if len(snippet) > remaining_chars:
            snippet = snippet[:remaining_chars].rstrip()

        # Don't include source labels in context to avoid them appearing in output
        context_parts.append(snippet)
        total_chars += len(snippet)

    return "\n\n".join(context_parts), len(context_parts)


@lru_cache(maxsize=2048)
def _cached_retrieved_context(
    normalized_question: str,
    candidate_k: int,
    final_k: int,
    chars_per_chunk: int,
    max_context_chars: int,
) -> tuple[str, int]:
    return get_retrieved_context(
        normalized_question,
        candidate_k=candidate_k,
        final_k=final_k,
        chars_per_chunk=chars_per_chunk,
        max_context_chars=max_context_chars,
    )


@lru_cache(maxsize=16)
def _chat_llm(model_name: str, max_tokens: int, temperature: float) -> ChatOpenAI:
    return ChatOpenAI(model_name=model_name, temperature=temperature, max_tokens=max_tokens)


def _compact_system_prompt(*, context: str, strict_mode: bool, response_style: str) -> str:
    context_block = context if context else "No relevant NCERT context retrieved."
    return (
        "You are an NCERT-aligned Class 11-12 Chemistry and Physics tutor.\n"
        "Use retrieved context first. Keep answers accurate, exam-relevant, and concise unless asked for detail.\n"
        "Never change the target system asked by the user (example: dipole axial field must stay dipole, not ring/disc/shell).\n"
        "If pronouns like this/that/these appear, resolve using chat history.\n"
        "For formulas/steps, prefer clean markdown and compact structure.\n"
        "IMPORTANT equation style: write equations in plain readable text, not LaTeX code.\n"
        "Use forms like: E = (1/(4π ε₀)) * (2p/x^3), never use { } blocks or backslash commands.\n"
        "For derivations, give logical step-by-step progression and avoid decorative bullet spam.\n"
        "Never end mid-step or mid-sentence; response must end with a clear final conclusion line.\n"
        "If strict textbook mode is yes, do not add outside facts.\n\n"
        f"Response style rule: {response_style}\n"
        f"Strict textbook mode: {'yes' if strict_mode else 'no'}\n\n"
        f"Retrieved NCERT Context:\n{context_block}"
    )


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


def trim_history(history: list[dict[str, str]] | None) -> list[dict[str, str]]:
    if not history:
        return []

    trimmed_history: list[dict[str, str]] = []
    for msg in history[-MAX_HISTORY_MESSAGES:]:
        role = str(msg.get("role", "")).strip()
        if role not in {"user", "assistant"}:
            continue

        content = str(msg.get("content", "")).strip()
        if not content:
            continue

        trimmed_history.append(
            {
                "role": role,
                "content": content[:MAX_HISTORY_CHARS_PER_MESSAGE],
            }
        )

    return trimmed_history


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

    budget = _adaptive_chat_budget(question)
    history = trim_history(history)[-budget["history_messages"] :]

    normalized_question = " ".join(question.strip().lower().split())
    context, chunk_count = _cached_retrieved_context(
        normalized_question,
        budget["candidate_k"],
        budget["final_k"],
        budget["chars_per_chunk"],
        budget["max_context_chars"],
    )
    used_context = bool(context.strip())
    strict_mode = is_textbook_only_mode(question)

    if strict_mode and not used_context:
        return ChatResponse(
            answer="The provided materials do not contain information relevant to this question.",
            used_context=False,
            context_chunks=0,
        )

    response_style = _response_style_instructions(question)

    system_prompt = _compact_system_prompt(
        context=context if used_context else "",
        strict_mode=strict_mode,
        response_style=response_style,
    )

    messages = build_conversation_messages(history, system_prompt, question)

    llm = _chat_llm(CHAT_MODEL, budget["max_tokens"], 0.0)
    result = llm.invoke(messages)

    answer_raw = str(result.content).strip()
    finish_reason = _extract_finish_reason(result)

    # If generation stopped due to length or looks cut off, request only the missing tail.
    if finish_reason == "length" or _looks_incomplete(answer_raw):
        continuation_llm = _chat_llm(CHAT_MODEL, min(450, CHAT_MAX_TOKENS), 0.0)
        continuation = continuation_llm.invoke(
            [
                *messages,
                AIMessage(content=answer_raw),
                HumanMessage(
                    content=(
                        "Continue only the missing remainder from the last line. "
                        "Do not repeat prior text. End with a clear final answer line."
                    )
                ),
            ]
        )
        continuation_text = str(continuation.content).strip()
        if continuation_text:
            answer_raw = f"{answer_raw}\n{continuation_text}".strip()

    answer = make_math_readable(answer_raw)
    answer = _finalize_answer_text(answer)
    answer = strip_source_citations(answer)

    return ChatResponse(
        answer=answer,
        used_context=used_context,
        context_chunks=chunk_count,
    )


def answer_question_with_image(question: str, image_base64: str, mime_type: str, history: list[dict[str, str]] | None = None) -> ChatResponse:
    if history is None:
        history = []

    budget = _adaptive_chat_budget(question)
    history = trim_history(history)[-budget["history_messages"] :]

    normalized_question = " ".join(question.strip().lower().split())
    context, chunk_count = _cached_retrieved_context(
        normalized_question,
        budget["candidate_k"],
        budget["final_k"],
        budget["chars_per_chunk"],
        budget["max_context_chars"],
    )
    used_context = bool(context.strip())
    strict_mode = is_textbook_only_mode(question)

    if strict_mode and not used_context:
        return ChatResponse(
            answer="The provided materials do not contain information relevant to this question.",
            used_context=False,
            context_chunks=0,
        )

    response_style = _response_style_instructions(question)

    prompt_text = (
        "You are an expert chemistry and physics tutor. Analyze the attached image and answer the question.\n"
        "Use retrieved context first where applicable and stay NCERT-aligned.\n"
        "Interpret formulas/graphs/diagrams clearly.\n"
        "Use markdown when helpful but keep concise for direct questions.\n"
        "Write equations in plain readable form (example: E = (1/(4π ε₀)) * (2p/x^3)); avoid LaTeX commands and braces.\n\n"
        f"Response style rule: {response_style}\n"
        f"Retrieved context:\n{context if used_context else 'No additional context retrieved.'}\n\n"
        f"Strict textbook mode: {'yes' if strict_mode else 'no'}\n"
    )
    
  
    if history:
        prompt_text += "\nConversation history:\n"
        for msg in history:
            role = msg.get("role", "")
            content = msg.get("content", "")
            prompt_text += f"{role}: {content}\n"
        prompt_text += "\n"
    
    prompt_text += f"Current question: {question}"

    # Validate base64 early to return clean client error for malformed payloads.
    base64.b64decode(image_base64, validate=True)

    vision_llm = _chat_llm(VISION_CHAT_MODEL, min(VISION_CHAT_MAX_TOKENS, budget["max_tokens"] + 200), 0.0)
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
    answer = _finalize_answer_text(answer)
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
    return content[:NOTES_MAX_ATTACHMENT_CHARS_PER_FILE]


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
    total_attachment_chars = 0

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

        cleaned = section_text.strip()
        if cleaned:
            remaining = NOTES_MAX_TOTAL_ATTACHMENT_CHARS - total_attachment_chars
            if remaining <= 0:
                break
            if len(cleaned) > remaining:
                cleaned = cleaned[:remaining].rstrip()

            extracted_sections.append(f"Source: {name}\n{cleaned}")
            total_attachment_chars += len(cleaned)

    context_blocks: list[str] = []
    if details.strip():
        context_blocks.append(f"User details:\n{details.strip()[:NOTES_MAX_DETAILS_CHARS]}")
    if extracted_sections:
        context_blocks.append("Extracted content from files/images:\n" + "\n\n".join(extracted_sections))

    context_text = "\n\n".join(context_blocks) if context_blocks else "No extra context provided."

    llm = _chat_llm(NOTES_MODEL, NOTES_MAX_TOKENS, 0.2)
    prompt = (
        "You are a school note generator. Write complete, exam-ready notes in markdown.\n"
        "Follow this exact output format with all section headings present:\n"
        "## All topic overview\n"
        "## Key Concepts\n"
        "## Important Points\n"
        "## Formulas and Examples\n"
        "## Quick Revision Checklist\n"
        "Formatting rules:\n"
        "- Use clean markdown only.\n"
        "- Keep bullets simple using '-' and numbered steps as '1. 2. 3.'.\n"
        "- Do not output duplicate bullets, decorative symbols, or broken numbering.\n"
        "- Keep equations in plain readable text; never use LaTeX commands, braces, or escaped symbols.\n"
        "- Use readable forms like: E = (1/(4π ε₀)) * (2p/x^3), v = u + at, F = ma.\n"
        "- Keep paragraph spacing clean (one blank line between sections).\n"
        "- Avoid incomplete endings; always finish with the checklist section.\n"
        "Content rules:\n"
        "- Ground in user details and attachment context first when available.\n"
        "- Include definitions, core ideas, derivation cues where relevant, and 1-2 quick examples.\n"
        "- Keep concise but complete for revision use.\n\n"
        f"Topic: {topic.strip()}\n\n"
        f"Context:\n{context_text}"
    )

    result = llm.invoke([HumanMessage(content=prompt)])
    note_raw = str(result.content).strip()
    finish_reason = _extract_finish_reason(result)

    if finish_reason == "length" or _looks_incomplete(note_raw):
        continuation_llm = _chat_llm(NOTES_MODEL, min(420, NOTES_MAX_TOKENS), 0.2)
        continuation = continuation_llm.invoke(
            [
                HumanMessage(content=prompt),
                AIMessage(content=note_raw),
                HumanMessage(
                    content=(
                        "Continue only the missing remainder. "
                        "Do not repeat previous text. "
                        "Ensure the output ends after completing '## Quick Revision Checklist'."
                    )
                ),
            ]
        )
        continuation_text = str(continuation.content).strip()
        if continuation_text:
            note_raw = f"{note_raw}\n{continuation_text}".strip()

    note = make_math_readable(note_raw)
    note = _finalize_notes_text(note)

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


@app.delete("/collab/rooms/{room_id}")
def collab_delete_room(room_id: str, user_email: str = "") -> dict[str, Any]:
    email = _sanitize_email(user_email)
    if not email:
        raise HTTPException(status_code=400, detail="User email is required.")

    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")

        if _sanitize_email(room.get("owner_email", "")) != email:
            raise HTTPException(status_code=403, detail="Only the collab owner can delete this room.")

        del COLLAB_ROOMS[room_id]

    return {"deleted": True, "room_id": room_id}


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


@app.post("/collab/rooms/{room_id}/remove-member")
def collab_remove_member(room_id: str, payload: CollabRemoveMemberRequest) -> dict[str, Any]:
    owner_email = _sanitize_email(payload.owner_email)
    member_email = _sanitize_email(payload.member_email)

    with COLLAB_LOCK:
        _cleanup_collab_state_if_due()
        room = COLLAB_ROOMS.get(room_id)
        if room is None:
            raise HTTPException(status_code=404, detail="Collab room not found.")

        if _sanitize_email(room.get("owner_email", "")) != owner_email:
            raise HTTPException(status_code=403, detail="Only the collab owner can remove members.")

        if member_email == owner_email:
            raise HTTPException(status_code=400, detail="The collab owner cannot remove themselves.")

        existing = next(
            (m for m in room["members"] if _sanitize_email(m.get("email", "")) == member_email),
            None,
        )
        if existing is None:
            raise HTTPException(status_code=404, detail="Member not found in this collab.")

        room["members"] = [
            member for member in room["members"]
            if _sanitize_email(member.get("email", "")) != member_email
        ]
        room.setdefault("member_emails", set()).discard(member_email)
        _add_room_message(
            room,
            owner_email,
            room.get("owner_name", "Owner"),
            "system",
            f"{existing.get('name', 'A member')} was removed from the collab.",
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
                "attachments": [
                    {
                        "name": item.name.strip(),
                        "base64_data": item.base64_data,
                        "mime_type": item.mime_type.strip(),
                    }
                    for item in payload.attachments
                ],
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
