from pathlib import Path

from dotenv import load_dotenv
from PyPDF2 import PdfReader
from langchain_openai import OpenAIEmbeddings
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS


PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data"
VECTOR_DIR = PROJECT_ROOT / "vectorstore" / "faiss_index"




def get_pdf_files() -> list[Path]:
    return sorted(DATA_DIR.glob("*.pdf"))


def extract_text_from_pdfs(pdf_paths: list[Path]) -> str:
    text = ""
    for pdf_path in pdf_paths:
        reader = PdfReader(str(pdf_path))
        for page in reader.pages:
            text += page.extract_text() or ""
    return text


def split_text(text: str) -> list[str]:
    text_splitter = RecursiveCharacterTextSplitter(
        separators=["\n\n", "\n", ". ", " ", ""],
        chunk_size=1000,
        chunk_overlap=200,
        length_function=len,
    )
    return text_splitter.split_text(text)


def build_vector_store(chunks: list[str]) -> FAISS:
    embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
    return FAISS.from_texts(texts=chunks, embedding=embeddings)


def main() -> None:
    load_dotenv()

    pdf_files = get_pdf_files()

    raw_text = extract_text_from_pdfs(pdf_files)

    chunks = split_text(raw_text)
    vector_store = build_vector_store(chunks)

    VECTOR_DIR.parent.mkdir(parents=True, exist_ok=True)
    vector_store.save_local(str(VECTOR_DIR))

    print(f"Indexed {len(pdf_files)} PDF file(s)")
    print(f"Saved vector database to: {VECTOR_DIR}")


if __name__ == "__main__":
    main()

