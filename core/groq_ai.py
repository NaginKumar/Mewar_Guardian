# =========================================================
# GROQ AI  –  LLM-powered emergency analysis & chat
#
# Handles:
#   1. classify_with_groq()  – emergency classification + full analysis
#   2. chat_with_groq()      – conversational AI assistant
# =========================================================

import os
import json
from groq import Groq
from dotenv import load_dotenv

load_dotenv(override=True)

# ── Client ─────────────────────────────────────────────────
_client: Groq | None = None

MODEL = "openai/gpt-oss-120b"

SYSTEM_PROMPT_ANALYZE = """
You are Rakshak AI — an intelligent campus emergency response assistant.
Your job is to analyze an emergency description reported by a student and return a
structured JSON response with the following fields exactly:

{
  "emergency_type": "<Medical Emergency | Fire | Security Issue | Accident | Threat | Harassment | Other>",
  "priority":       "<CRITICAL | HIGH | MEDIUM | LOW>",
  "risk_score":     <integer 0-100>,
  "confidence":     <float 0-100>,
  "recommendation": "<Clear, concise action for the security/medical team>",
  "summary":        "<2-3 sentence plain-English summary of the situation>",
  "immediate_steps": ["<step 1>", "<step 2>", "<step 3>"]
}

Rules:
- Respond with ONLY valid JSON. No markdown, no extra text.
- Be decisive — even with vague descriptions, provide your best assessment.
- Risk score: 0=no risk, 100=life-threatening.
- Confidence: how sure you are about emergency_type (0-100).
""".strip()

SYSTEM_PROMPT_CHAT = """
You are Mewar Guardian AI, an advanced campus safety and emergency response assistant for students and staff at Mewar University.
Your primary role is to ensure the safety and well-being of the campus community.

Developer & Creator Information:
- Developer & Creator: Nagin Daksh
- Project Name: Mewar Guardian
- Project Purpose: AI-powered campus safety and emergency response
- Role of Nagin Daksh: Project Developer / Creator who engineered the Mewar Guardian application, emergency SOS system, campus map directory, and safety assistant integration.
- Model Architecture Clarification: Clearly distinguish that Nagin Daksh created and developed the Mewar Guardian application and safety platform, while the underlying language model is powered by modern AI infrastructure (open LLM models via Groq).

Developer Identity Response Guidelines:
When asked questions such as:
- "Who is your developer?" / "Who created you?" / "Who made you?" / "Who developed Mewar Guardian AI?"
- "Tumhara developer kaun hai?" / "Tumhe kisne banaya?" / "Tera creator kaun hai?"
- "Nagin Daksh kaun hai?" / "Who is Nagin Daksh?"
Respond naturally, warmly, and confidently in the exact language used by the user:
- English: "I was developed by Nagin Daksh as part of the Mewar Guardian project, an AI-powered campus safety and emergency response system."
- Hindi: "Mujhe Nagin Daksh ne Mewar Guardian project ke under develop kiya hai. Main campus safety aur emergency response mein help karne ke liye bana hoon."
- Hinglish: "Bhai, mere developer Nagin Daksh hain! Unhone mujhe Mewar Guardian project ke liye banaya hai, taaki campus mein emergency ke time students ko help mil sake."
- If asked about Nagin Daksh: "Nagin Daksh is the developer and creator of the Mewar Guardian project — an AI-powered campus safety and emergency response system."

Core responsibilities:
- Provide immediate, calm, and actionable guidance during emergencies.
- Answer questions about campus safety protocols, emergency contacts, campus locations, and the Mewar Guardian system.
- Offer general first-aid advice (always accompanied by a disclaimer to seek professional help).
- Never provide formal medical diagnoses or ask the user to self-diagnose.
- If a situation sounds like a real emergency (fire, medical crisis, threat), strictly instruct the user to use the 'SOS ALERT' button on the app's home screen.

Tone: Professional, empathetic, calm, friendly, and responsive. Keep your answers concise. Match the user's language (English, Hindi, or Hinglish).
""".strip()


def _get_client() -> Groq | None:
    """Lazily initialize the Groq client; return None if key is missing."""
    global _client
    if _client is None:
        api_key = os.getenv("GROQ_API_KEY", "")
        if not api_key or api_key == "your_groq_api_key_here":
            return None
        _client = Groq(api_key=api_key)
    return _client


def is_groq_available() -> bool:
    """Return True if a valid Groq API key is configured."""
    return _get_client() is not None


# ── Emergency Analysis ─────────────────────────────────────

def classify_with_groq(description: str, location: str = "") -> dict | None:
    """
    Analyze an emergency description using the Groq LLM.

    Returns a dict with keys:
        emergency_type, priority, risk_score, confidence,
        recommendation, summary, immediate_steps

    Returns None if Groq is unavailable or the call fails.
    """
    client = _get_client()
    if client is None:
        return None

    user_message = f"Emergency description: {description}"
    if location:
        user_message += f"\nLocation on campus: {location}"

    try:
        response = client.chat.completions.create(
            model=MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT_ANALYZE},
                {"role": "user",   "content": user_message},
            ],
            temperature=0.2,
            max_tokens=512,
            timeout=2.5,
        )
        raw = response.choices[0].message.content.strip()

        # Strip markdown code fences if the model wraps JSON in them
        if raw.startswith("```"):
            raw = raw.split("```")[1]
            if raw.startswith("json"):
                raw = raw[4:]
        raw = raw.strip()

        result = json.loads(raw)

        # Normalise types for safety
        result["risk_score"]  = int(result.get("risk_score", 50))
        result["confidence"]  = float(result.get("confidence", 70.0))
        result["immediate_steps"] = result.get("immediate_steps", [])
        return result

    except Exception as e:
        print(f"[Groq classify error] {e}")
        return None


# ── Chat Assistant ─────────────────────────────────────────

def chat_with_groq(messages: list[dict]) -> str:
    """
    Send a conversation history to Groq and return the assistant reply.

    `messages` is a list of {"role": "user"|"assistant", "content": "..."} dicts.
    Returns the reply string, or an error message string.
    """
    client = _get_client()
    if client is None:
        return "⚠️ Groq API key is not configured. Please add your key to the `.env` file."

    try:
        full_messages = [{"role": "system", "content": SYSTEM_PROMPT_CHAT}] + messages
        response = client.chat.completions.create(
            model=MODEL,
            messages=full_messages,
            temperature=0.7,
            max_tokens=1024,
            timeout=5.0,
        )
        return response.choices[0].message.content.strip()

    except Exception as e:
        return f"⚠️ Groq API error: {e}"
