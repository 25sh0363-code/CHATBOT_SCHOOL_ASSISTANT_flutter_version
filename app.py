import streamlit as st
from dotenv import load_dotenv
from PyPDF2 import PdfReader
from langchain_text_splitters import CharacterTextSplitter
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import FAISS
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory
from langchain_core.prompts import PromptTemplate
from htmltemplates import css, user_template, bot_template


def get_pdf_text(pdf_files):
    text = ""
    for pdf in pdf_files:
        reader = PdfReader(pdf)
        for page in reader.pages:
            text += page.extract_text() or ""
    return text


def get_existing_vector_store():
    try:
        return FAISS.load_local("vectorstore/faiss_index",OpenAIEmbeddings(),allow_dangerous_deserialization=True,)
    except Exception:
        return None

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
    embeddings = OpenAIEmbeddings()
    vector_store = FAISS.from_texts(texts=text_chunks, embedding=embeddings)
    return vector_store

def get_conversation_chain(vector_store):
    qa_prompt = PromptTemplate(
        template=(
            "You are a chemistry and physics tutor.\n"
            "Use the retrieved context first.\n"
            "If context is incomplete, use your own subject knowledge to answer clearly.\n"
            "If you use your own knowledge, mention: 'Based on general chemistry/physics knowledge'.\n"
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
    st.session_state.chat_history = response["chat_history"]

    for i, message in enumerate(st.session_state.chat_history):
        if i % 2 == 0:
            st.write(user_template.replace("{{MSG}}", message.content), unsafe_allow_html=True)
        else:
            st.write(bot_template.replace("{{MSG}}", message.content), unsafe_allow_html=True)


def main():
    load_dotenv()
    st.set_page_config(page_title="YOUR CHEMISTRY AND PHYSICS ASSISTANT", page_icon=":atom_symbol:", layout="wide")
    st.write(css, unsafe_allow_html=True)

    if "conversation" not in st.session_state:
        st.session_state.conversation = None
    if "chat_history" not in st.session_state:
        st.session_state.chat_history = None

    if st.session_state.conversation is None:
        existing_vector_store = get_existing_vector_store()
        if existing_vector_store is not None:
            st.session_state.conversation = get_conversation_chain(existing_vector_store)
    

    st.title("School Assistant")
    st.caption("Ask from your default knowledge base, then optionally enhance with extra PDFs.")

    if st.session_state.conversation is None:
        st.info("No usable default data found yet. Put PDFs in /data or upload PDFs from sidebar and click Process.")

    user_question = st.text_input(
        "Message",
        key="user_question",
        placeholder="Ask a question about physics or chemistry...",
        label_visibility="collapsed",
    )
    if user_question:
        handle_user_input(user_question)

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

                existing_vector_store = get_existing_vector_store()
                if existing_vector_store is not None:
                    existing_vector_store.merge_from(uploaded_vector_store)
                    final_vector_store = existing_vector_store
                else:
                    final_vector_store = uploaded_vector_store

                st.success("PDF files processed successfully!")

                st.session_state.conversation = get_conversation_chain(final_vector_store)



if __name__ == "__main__":
    main()