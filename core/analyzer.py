# =========================================================
# ANALYZER  –  smart_analyze + calculate_priority
#
# Priority order:
#   1. Groq LLM  (if API key is set)       → richest analysis
#   2. sklearn LogisticRegression fallback  → always available
# =========================================================

from core.ai_model import classify_emergency
from core.groq_ai import classify_with_groq, is_groq_available


# ── Priority Detection (keyword-based, used as fallback) ───

def calculate_priority(text: str) -> str:
    """Return LOW / MEDIUM / HIGH based on keyword presence."""
    t = text.lower()

    high_words = [
        "unconscious", "bleeding", "fire", "burning", "serious",
        "attack", "attacking", "threat", "threatening", "fight",
        "fighting", "not breathing", "critical", "severe", "danger", "dangerous"
    ]
    medium_words = [
        "injured", "injury", "accident", "fallen", "fall", "hurt", "smoke"
    ]

    for word in high_words:
        if word in t:
            return "HIGH"
    for word in medium_words:
        if word in t:
            return "MEDIUM"
    return "LOW"


# ── Smart Analysis (Groq-first, sklearn fallback) ──────────

def smart_analyze(text: str, location: str = "") -> tuple:
    """
    Analyze emergency text using Groq LLM (primary) or sklearn (fallback).

    Returns
    -------
    prediction    : str   – emergency category
    confidence    : float – AI confidence (0-100)
    priority      : str   – CRITICAL | HIGH | MEDIUM | LOW
    risk_score    : int   – 0-100
    recommendation: str   – suggested action
    groq_result   : dict | None – full Groq response (None if fallback used)
    """

    # ── 1. Try Groq LLM ────────────────────────────────────
    if is_groq_available():
        groq_result = classify_with_groq(text, location)
        if groq_result:
            prediction     = groq_result.get("emergency_type", "Other")
            confidence     = groq_result.get("confidence", 80.0)
            priority       = groq_result.get("priority", "MEDIUM")
            risk_score     = groq_result.get("risk_score", 50)
            recommendation = groq_result.get("recommendation", "")
            return prediction, confidence, priority, risk_score, recommendation, groq_result

    # ── 2. sklearn fallback ─────────────────────────────────
    prediction, confidence = classify_emergency(text)
    t = text.lower()

    keyword_groups = {
        "Fire":     ["fire", "flame", "burning", "smoke", "gas leak"],
        "Medical":  ["unconscious", "fainted", "faint", "bleeding", "not breathing",
                     "chest pain", "seizure", "collapsed", "ambulance", "headache", "pain"],
        "Accident": ["accident", "crash", "collision", "hit by", "injured",
                     "injury", "fell", "fall", "bike accident"],
        "Security": ["fight", "fighting", "attack", "attacking", "weapon", "theft", "robbery", "suspicious"],
        "Threat":   ["threat", "threatening", "dhamki"],
        "Harassment": ["harass", "harassment", "disturb", "pareshaan", "following me"]
    }

    scores = {
        name: sum(1 for word in words if word in t)
        for name, words in keyword_groups.items()
    }
    keyword_type = max(scores, key=scores.get)

    negations = ["no fire", "not a fire", "false alarm", "no emergency", "just testing", "no medical", "not an accident", "nobody is injured", "not breathing"]
    is_negated = any(n in t for n in negations) and "but" not in t

    # Use keyword fallback only if no strong negation (except "not breathing" which is a real emergency)
    if scores[keyword_type] > 0 and not (is_negated and "not breathing" not in t):
        prediction = keyword_type
        confidence = max(confidence, min(99.0, 75.0 + scores[keyword_type] * 6))
    elif is_negated and "not breathing" not in t:
        prediction = "Other"

    priority = calculate_priority(text)

    critical_words = ["not breathing", "unconscious", "heavy bleeding",
                      "major fire", "gas leak", "weapon", "critical"]
    high_words_    = ["fire", "burning", "attack", "attacking", "serious",
                      "severe", "danger", "threat", "bleeding"]
    medium_words_  = ["injured", "injury", "accident", "fallen", "fall",
                      "hurt", "smoke"]

    if any(w in t for w in critical_words):
        priority = "CRITICAL"
    elif any(w in t for w in high_words_):
        priority = "HIGH"
    elif any(w in t for w in medium_words_):
        priority = "MEDIUM"

    score_map = {"LOW": 25, "MEDIUM": 55, "HIGH": 80, "CRITICAL": 100}
    risk_score = score_map[priority]

    recommendations = {
        "Medical":  "Contact medical/ambulance support immediately and keep the area clear.",
        "Fire":     "Alert fire response, evacuate nearby people, and avoid entering the affected area.",
        "Security": "Alert security, keep a safe distance, and avoid confrontation.",
        "Threat":   "Dispatch security team to intercept the threat and secure the student.",
        "Harassment": "Dispatch security team to escort the student and investigate the harassment.",
        "Accident": "Send medical support, secure the area, and prevent further traffic movement.",
        "Other":    "Security should verify the report and decide the appropriate response."
    }
    recommendation = recommendations.get(prediction, recommendations["Other"])

    return prediction, confidence, priority, risk_score, recommendation, None
