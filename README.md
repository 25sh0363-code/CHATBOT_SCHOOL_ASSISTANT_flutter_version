# 🎓 School Assistant — Chemistry & Physics Chatbot

An AI-powered school assistant built to help students understand **Chemistry** and **Physics** through conversational Q&A, textbook-grounded retrieval, and optional image-based question analysis.

---

## ✨ Highlights

- 📘 Retrieval-augmented answers from PDF study material
- 💬 Conversational memory for follow-up questions
- 🖼️ Image + text question support
- ⚡ Streamlit web interface for easy use
- 🧠 Built with LangChain + OpenAI + FAISS

---

## 🛠 Tech Stack

- **Frontend/App**: Streamlit  
- **LLM & Embeddings**: OpenAI (`ChatOpenAI`, `OpenAIEmbeddings`)  
- **Orchestration**: LangChain  
- **Vector DB**: FAISS  
- **PDF Parsing**: PyPDF2  
- **Environment Management**: python-dotenv  

---

## 📂 Project Structure

- `app.py` — main Streamlit application logic  
- `htmltemplates.py` — chat UI templates/styles  
- `vectorstore/faiss_index` — persisted FAISS index  
- `.env` — API keys and environment config  

---

## 🚀 Run Locally

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

2. Add your API key in `.env`:
   ```env
   OPENAI_API_KEY=your_api_key_here
   ```

3. Start the app:
   ```bash
   streamlit run app.py
   ```

---

## 👨‍💻 Credits

- **Developer:** **Omi**  
- **AI Assistant Support:** **GitHub Copilot (GPT-5.3-Codex)** (helped to make ui changes and helped to make math functions given in responce readable)

---

## 📚 Learning Resources

- https://www.youtube.com/watch?v=74c3KaAXPvk  
- https://www.youtube.com/watch?v=dXxQ0LR-3Hg  

---

## 📌 Portfolio Note

This project demonstrates practical skills in:
- Retrieval-Augmented Generation (RAG)
- LLM app development
- Prompt design for educational assistants
- End-to-end deployment-ready Streamlit workflows
