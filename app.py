import streamlit as st
import streamlit.components.v1 as components
import base64
import re
from dotenv import load_dotenv
from PyPDF2 import PdfReader
from langchain_text_splitters import CharacterTextSplitter
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import FAISS
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory
from langchain_core.prompts import PromptTemplate
from langchain_core.messages import HumanMessage, AIMessage
from htmltemplates import css, user_template, bot_template


def make_math_readable(text: str) -> str:
    if not text:
        return text

    # Strip common LaTeX wrappers so formulas are readable in plain chat bubbles.
    text = text.replace("\\[", "").replace("\\]", "")
    text = text.replace("\\(", "").replace("\\)", "")

    # Convert frequent LaTeX commands to plain-text equivalents.
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


def get_pdf_text(pdf_files):
    text = ""
    for pdf in pdf_files:
        reader = PdfReader(pdf)
        for page in reader.pages:
            text += page.extract_text() or ""
    return text


def get_existing_vector_store():
    try:
        return FAISS.load_local(
            "vectorstore/faiss_index",
            get_embeddings(),
            allow_dangerous_deserialization=True,
        )
    except Exception:
        return None


@st.cache_resource(show_spinner=False)
def get_embeddings():
    return OpenAIEmbeddings()


@st.cache_resource(show_spinner=False)
def get_default_vector_store_cached():
    return get_existing_vector_store()

def get_text_chunks(text):
    text_splitter = CharacterTextSplitter(
        separator="\n",
        chunk_size=1000,
        chunk_overlap=200,
        length_function=len
    )
    chunks = text_splitter.split_text(text)
    return chunks

def get_vector_store(text_chunks):
    vector_store = FAISS.from_texts(texts=text_chunks, embedding=get_embeddings())
    return vector_store


def ensure_conversation_ready() -> bool:
    if st.session_state.conversation is not None:
        return True

    if st.session_state.vector_store is None:
        with st.spinner("Loading default knowledge base..."):
            st.session_state.vector_store = get_default_vector_store_cached()

    if st.session_state.vector_store is None:
        return False

    st.session_state.conversation = get_conversation_chain(st.session_state.vector_store)
    return True

def get_conversation_chain(vector_store):
    qa_prompt = PromptTemplate(
        template=(
            "You are a chemistry and physics tutor.\n"
            "Use the retrieved context first.\n"
            "If context is incomplete, use your own subject knowledge to answer clearly.\n"
            "If you use your own knowledge, mention: 'Based on general chemistry/physics knowledge'.\n"
            "if mentioned to refer to textbook,strictly refer to vector store retrieved context and do not make up any information.\n"
            "if no relevant information is found in the retrieved context, say 'The provided materials do not contain information relevant to this question.'\n"
            "Write equations in plain text only (example: R = sqrt(A^2 + B^2 + 2AB cos(theta))). Do not use LaTeX.\n"
            "Give concise, correct explanations and include examples when helpful.\n\n"
            "Context:\n{context}\n\n"
            "Question: {question}\n"
            "Answer:"
        ),
        input_variables=["context", "question"],
    )

    llm = ChatOpenAI(model_name="gpt-4.1-nano", temperature=0)
    memory = ConversationBufferMemory(memory_key="chat_history", return_messages=True)
    retriever = vector_store.as_retriever(
        search_type="mmr",
        search_kwargs={"k": 8, "fetch_k": 24},
    )

    conversation_chain = ConversationalRetrievalChain.from_llm(
        llm=llm,
        retriever=retriever,
        memory=memory,
        combine_docs_chain_kwargs={"prompt": qa_prompt},
    )
    return conversation_chain

def handle_user_input(user_question):
    if st.session_state.conversation is None:
        st.warning("No knowledge base is loaded. Build default DB first or upload PDFs and click Process.")
        return

    response = st.session_state.conversation({"question": user_question})
    for message in response["chat_history"]:
        if isinstance(message, AIMessage):
            message.content = make_math_readable(str(message.content))
    st.session_state.chat_history = response["chat_history"]


def get_retrieved_context(question: str) -> str:
    vector_store = st.session_state.get("vector_store")
    if vector_store is None:
        return ""

    docs = vector_store.as_retriever(
        search_type="mmr",
        search_kwargs={"k": 4, "fetch_k": 16},
    ).get_relevant_documents(question)

    if not docs:
        return ""

    return "\n\n".join(doc.page_content[:1200] for doc in docs)


def handle_user_input_with_image(user_question, image_file):
    image_bytes = image_file.getvalue()
    encoded = base64.b64encode(image_bytes).decode("utf-8")
    mime_type = image_file.type or "image/jpeg"
    retrieved_context = get_retrieved_context(user_question)

    prompt_text = (
        "You are a chemistry and physics tutor. Analyze the attached image and answer the question.\n"
        "Use retrieved textbook context first when relevant, then complete with your own knowledge.\n"
        "If the image includes formulas/structures/diagrams, interpret them clearly.\n\n"
        "Write equations in plain text only (example: R = sqrt(A^2 + B^2 + 2AB cos(theta))). Do not use LaTeX.\n"
        "if mentioned to refer to textbook,strictly refer to vector store retrieved context and do not make up any information.\n"
        "if no relevant information is found in the retrieved context, say 'The provided materials do not contain information relevant to this question.'\n"
        f"Retrieved context:\n{retrieved_context if retrieved_context else 'No additional context retrieved.'}\n\n"
        f"Question: {user_question}"
    )

    vision_llm = ChatOpenAI(model_name="gpt-4.1-mini", temperature=0)
    ai_message = vision_llm.invoke(
        [
            HumanMessage(
                content=[
                    {"type": "text", "text": prompt_text},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime_type};base64,{encoded}"},
                    },
                ]
            )
        ]
    )

    if st.session_state.chat_history is None:
        st.session_state.chat_history = []

    st.session_state.chat_history.append(HumanMessage(content=f"{user_question} (with image)"))
    st.session_state.chat_history.append(AIMessage(content=make_math_readable(str(ai_message.content))))


def render_chat_history():
    if not st.session_state.chat_history:
        return

    for i, message in enumerate(st.session_state.chat_history):
        if i % 2 == 0:
            st.write(user_template.replace("{{MSG}}", message.content), unsafe_allow_html=True)
        else:
            st.write(bot_template.replace("{{MSG}}", make_math_readable(str(message.content))), unsafe_allow_html=True)


                                                                
def main():
    load_dotenv()
    st.set_page_config(page_title="YOUR CHEMISTRY AND PHYSICS ASSISTANT", page_icon=":atom_symbol:", layout="wide")
    st.write(css, unsafe_allow_html=True)

    if "conversation" not in st.session_state:
        st.session_state.conversation = None
    if "chat_history" not in st.session_state:
        st.session_state.chat_history = None
    if "vector_store" not in st.session_state:
        st.session_state.vector_store = None

    st.title("School Assistant")
    st.caption("Ask from your default knowledge base, then optionally enhance with extra PDFs.")

    if st.session_state.conversation is None:
        st.info("Default knowledge base will load on first question. You can also upload PDFs from the sidebar and click Process.")

    user_question = st.chat_input("Ask a question about physics or chemistry...")
    add_image = st.file_uploader(
        "Upload an image to include in your question (optional)",
        type=["png", "jpg", "jpeg"],
        key="image_uploader",
    )
    if user_question:
        if not ensure_conversation_ready():
            st.warning("No knowledge base is loaded. Upload PDFs and click Process.")
            return

        if add_image is not None:
            handle_user_input_with_image(user_question, add_image)
        else:
            handle_user_input(user_question)

    render_chat_history()

    if st.session_state.chat_history:
        # Auto-scroll to latest message after rerender.
        components.html(
            """
            <script>
                window.parent.scrollTo(0, document.body.scrollHeight);
            </script>
            """,
            height=0,
        )

    with st.sidebar:
        st.subheader("Upload extra teacher material/important topic pdfs here to enhance the assistant's knowledge!(dont forget to click process after uploading)")
        pdf_files = st.file_uploader("Upload PDF",accept_multiple_files=True)
        if st.button("Process", key="process_button"):
            if not pdf_files:
                st.warning("Please upload at least one PDF first.")
                return

            with st.spinner("Processing PDF files..."): 

                raw_text = get_pdf_text(pdf_files)

                text_chunks = get_text_chunks(raw_text) 
                
                uploaded_vector_store = get_vector_store(text_chunks)

                existing_vector_store = st.session_state.vector_store
                if existing_vector_store is None:
                    existing_vector_store = get_default_vector_store_cached()
                if existing_vector_store is not None:
                    existing_vector_store.merge_from(uploaded_vector_store)
                    final_vector_store = existing_vector_store
                else:
                    final_vector_store = uploaded_vector_store

                st.success("PDF files processed successfully!")

                st.session_state.vector_store = final_vector_store
                st.session_state.conversation = get_conversation_chain(final_vector_store)
                get_default_vector_store_cached.clear()
        st.subheader("Quick math symbols to copy and paste")
        st.table(
            [
                {"Symbol": "theta", "Copy": "theta"},
                {"Symbol": "alpha", "Copy": "alpha"},
                {"Symbol": "beta", "Copy": "beta"},
                {"Symbol": "gamma", "Copy": "gamma"},
                {"Symbol": "Delta", "Copy": "Delta"},
                {"Symbol": "times", "Copy": "times"},
                {"Symbol": "cdot", "Copy": "cdot"},
                {"Symbol": "cos", "Copy": "cos"},
                {"Symbol": "sin", "Copy": "sin"},
                {"Symbol": "tan", "Copy": "tan"},
                {"Symbol": "pi", "Copy": "pi"},
            ]
        )



if __name__ == "__main__":
    main()