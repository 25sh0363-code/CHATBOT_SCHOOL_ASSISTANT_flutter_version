import os
import base64
import re
import tempfile
import urllib.request
import zipfile
from functools import lru_cache
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from langchain_community.vectorstores import FAISS
from langchain_core.messages import HumanMessage
from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from pydantic import BaseModel, Field

EMBEDDING_MODEL = "text-embedding-3-small"
CHAT_MODEL = "gpt-4.1-nano"
VECTORSTORE_DIR = Path("vectorstore/faiss_index")
VECTORSTORE_INDEX_PATH = VECTORSTORE_DIR / "index.faiss"


class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=3000)


class ImageChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=3000)
    image_base64: str = Field(min_length=20)
    mime_type: str = "image/jpeg"


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


def get_retrieved_context(question: str) -> tuple[str, int]:
    vector_store = get_vector_store()
    docs = vector_store.as_retriever(
        search_type="similarity",
        search_kwargs={"k": 8},
    ).get_relevant_documents(question)

    if not docs:
        return "", 0

    return "\n\n".join(doc.page_content[:1200] for doc in docs), len(docs)


def answer_question(question: str) -> ChatResponse:
    context, chunk_count = get_retrieved_context(question)
    used_context = bool(context.strip())

    prompt = (
        "You are a chemistry and physics tutor.\n"
        "Use the retrieved context first.\n"
        "If context is incomplete, use your own subject knowledge to answer clearly.\n"
        "If you use your own knowledge, mention: 'Based on general chemistry/physics knowledge'.\n"
        "If the user explicitly asks to answer from textbook/materials only, strictly use retrieved context and do not add outside facts.\n"
        "Only in that textbook-only mode: if no relevant information is found, say 'The provided materials do not contain information relevant to this question.'.\n"
        "Write equations in plain text only. Do not use LaTeX.\n\n"
        f"Context:\n{context if used_context else 'No relevant context retrieved.'}\n\n"
        f"Question: {question}\n"
        "Answer:"
    )

    llm = ChatOpenAI(model_name=CHAT_MODEL, temperature=0)
    result = llm.invoke(prompt)

    return ChatResponse(
        answer=make_math_readable(str(result.content).strip()),
        used_context=used_context,
        context_chunks=chunk_count,
    )


def answer_question_with_image(question: str, image_base64: str, mime_type: str) -> ChatResponse:
    context, chunk_count = get_retrieved_context(question)
    used_context = bool(context.strip())

    prompt_text = (
        "You are a chemistry and physics tutor. Analyze the attached image and answer the question.\n"
        "Use retrieved textbook context first when relevant, then complete with your own knowledge.\n"
        "If the image includes formulas/structures/diagrams, interpret them clearly.\n\n"
        "Write equations in plain text only (example: R = sqrt(A^2 + B^2 + 2AB cos(theta))). Do not use LaTeX.\n"
        "If the user explicitly asks to answer from textbook/materials only, strictly use retrieved context and do not add outside facts.\n"
        "Only in that textbook-only mode: if no relevant information is found, say 'The provided materials do not contain information relevant to this question.'.\n"
        f"Retrieved context:\n{context if used_context else 'No additional context retrieved.'}\n\n"
        f"Question: {question}"
    )

    # Validate base64 early to return clean client error for malformed payloads.
    base64.b64decode(image_base64, validate=True)

    vision_llm = ChatOpenAI(model_name="gpt-4.1-mini", temperature=0)
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

    return ChatResponse(
        answer=make_math_readable(str(ai_message.content).strip()),
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
        return answer_question(payload.question.strip())
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
