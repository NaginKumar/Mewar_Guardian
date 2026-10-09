# =========================================================
# AI MODEL  –  Training data + vectorizer + classifier
# =========================================================

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression

# -------------------------
# TRAINING DATA
# -------------------------

training_text = [

    # Medical
    "student is unconscious",
    "person is not breathing",
    "medical emergency",
    "student needs medical help",
    "someone is seriously injured",
    "person is bleeding",
    "student has fainted",

    # Fire
    "there is a fire",
    "building is burning",
    "fire in hostel",
    "smoke coming from room",
    "there is a burning smell",

    # Security
    "someone is fighting",
    "students are fighting",
    "person is threatening students",
    "security problem",
    "someone is attacking",
    "suspicious person",

    # Accident
    "car accident happened",
    "bike accident",
    "student fell from bike",
    "road accident",
    "vehicle collision",

    # Other
    "lost mobile phone",
    "lost wallet",
    "normal complaint",
    "need help",
    "other problem"
]

training_labels = [

    # Medical
    "Medical Emergency",
    "Medical Emergency",
    "Medical Emergency",
    "Medical Emergency",
    "Medical Emergency",
    "Medical Emergency",
    "Medical Emergency",

    # Fire
    "Fire",
    "Fire",
    "Fire",
    "Fire",
    "Fire",

    # Security
    "Security Issue",
    "Security Issue",
    "Security Issue",
    "Security Issue",
    "Security Issue",
    "Security Issue",

    # Accident
    "Accident",
    "Accident",
    "Accident",
    "Accident",
    "Accident",

    # Other
    "Other",
    "Other",
    "Other",
    "Other",
    "Other"
]

# -------------------------
# TRAIN MODEL
# -------------------------

training_text.extend([
    "someone is threatening me",
    "getting death threats",
    "dhamki de raha hai",
    "following me everywhere",
    "someone is harassing me",
    "harassment by senior",
    "this is not a fire",
    "there is no fire",
    "it is a false alarm",
    "nobody is injured",
    "just testing",
    "no medical emergency",
    "not an accident"
])

training_labels.extend([
    "Threat", "Threat", "Threat",
    "Harassment", "Harassment", "Harassment",
    "Other", "Other", "Other", "Other", "Other", "Other", "Other"
])

vectorizer = TfidfVectorizer(ngram_range=(1, 2))
X = vectorizer.fit_transform(training_text)

model = LogisticRegression(max_iter=1000)
model.fit(X, training_labels)


# -------------------------
# CLASSIFY
# -------------------------

def classify_emergency(text: str):
    """Return (predicted_label, confidence_percent) for free-text input."""
    # Simple explicit negation override for absolute safety
    t = text.lower()
    negations = ["no fire", "not a fire", "false alarm", "no emergency", "just testing", "no medical", "not an accident", "nobody is injured", "not breathing"]
    
    if any(n in t for n in negations) and "but" not in t:
        if "not breathing" in t:
            pass # this is an actual emergency!
        else:
            return "Other", 95.0

    text_vector = vectorizer.transform([text])
    prediction = model.predict(text_vector)[0]
    probabilities = model.predict_proba(text_vector)
    confidence = max(probabilities[0]) * 100
    return prediction, confidence
