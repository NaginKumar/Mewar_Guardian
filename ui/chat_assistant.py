# =========================================================
# CHAT ASSISTANT  –  Groq-powered campus safety chatbot
# =========================================================

import streamlit as st
from core.groq_ai import chat_with_groq, is_groq_available

# Suggested quick questions
QUICK_QUESTIONS = [
    "What should I do if I see a fire in a hostel?",
    "How do I perform basic first aid for a bleeding wound?",
    "Someone fainted in class — what are the steps?",
    "There's a fight near the canteen. How should I stay safe?",
    "How does Rakshak AI classify emergencies?",
    "What is the fastest way to report an emergency?",
    "Who do I contact for a medical emergency on campus?",
    "What should I do if I smell gas?",
]


def render():
    """Render the AI Chat Assistant page."""

    st.markdown("""
    <div style="padding:24px 28px;border-radius:20px;
                background:linear-gradient(135deg,#f0f7ff,#e8f4ff);
                border:1px solid #c7dff7;margin-bottom:20px;">
        <div style="font-size:26px;font-weight:800;color:#1e3a5f;">
            🤖 Rakshak AI Chat Assistant
        </div>
        <div style="color:#52708f;margin-top:6px;font-size:14px;">
            Ask anything about campus safety, emergency procedures, or first-aid guidance.
            Powered by <b>Groq</b> (openai/gpt-oss-120b).
        </div>
    </div>
    """, unsafe_allow_html=True)

    # ── API key warning ────────────────────────────────────
    if not is_groq_available():
        st.warning(
            "⚠️ **Groq API key not configured.**  \n"
            "Add `GROQ_API_KEY=your_key` to your `.env` file and restart the app."
        )
        st.stop()

    # ── Init chat history ──────────────────────────────────
    if "chat_messages" not in st.session_state:
        st.session_state.chat_messages = []

    # ── Quick question buttons ─────────────────────────────
    with st.expander("💡 Quick Questions — click to ask", expanded=False):
        cols = st.columns(2)
        for i, question in enumerate(QUICK_QUESTIONS):
            with cols[i % 2]:
                if st.button(question, key=f"quick_{i}", use_container_width=True):
                    _send_message(question)
                    st.rerun()

    st.markdown("---")

    # ── Chat history display ───────────────────────────────
    for msg in st.session_state.chat_messages:
        with st.chat_message(msg["role"]):
            st.markdown(msg["content"])

    # ── Chat input ─────────────────────────────────────────
    if prompt := st.chat_input("Ask Rakshak AI anything about campus safety…"):
        _send_message(prompt)
        st.rerun()

    # ── Clear chat ─────────────────────────────────────────
    if st.session_state.chat_messages:
        if st.button("🗑️ Clear Conversation", use_container_width=False):
            st.session_state.chat_messages = []
            st.rerun()


def _send_message(user_text: str):
    """Add user message, get Groq reply, append both to session history."""
    st.session_state.chat_messages.append(
        {"role": "user", "content": user_text}
    )

    reply = chat_with_groq(st.session_state.chat_messages)

    st.session_state.chat_messages.append(
        {"role": "assistant", "content": reply}
    )
