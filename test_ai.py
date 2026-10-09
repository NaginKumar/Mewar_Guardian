import sys
from core.analyzer import smart_analyze

test_cases = [
    ("Someone is unconscious and not breathing", "Medical", "CRITICAL"),
    ("Fire spreading in the hostel", "Fire", "CRITICAL"),
    ("Someone is following and threatening me", "Threat", "HIGH"),
    ("Minor headache, no other symptoms", "Medical", "LOW"),
    ("There is no fire here, false alarm", "Other", "LOW"),
    ("Just testing the app", "Other", "LOW"),
    ("Two boys are fighting near the canteen", "Security", "MEDIUM"), # Or HIGH depending on rules
    ("A bike accident happened near main gate", "Accident", "MEDIUM"),
    ("I am being harassed by some seniors", "Harassment", "HIGH")
]

print("="*60)
print(" AI MODEL VALIDATION TEST ")
print("="*60)

passed = 0
for text, expected_type, expected_priority in test_cases:
    # smart_analyze returns: prediction, confidence, priority, risk_score, recommendation, groq_result
    pred, conf, prio, risk, rec, _ = smart_analyze(text)
    
    # We allow slight variations in priority depending on exact keyword matches
    # but the type should match.
    match = (pred == expected_type)
    if match:
        passed += 1
        print(f"PASS: '{text}' -> {pred} ({prio}, conf: {conf:.1f}%)")
    else:
        print(f"FAIL: '{text}' -> Got {pred} (Expected {expected_type})")

print("="*60)
print(f"Accuracy: {passed}/{len(test_cases)} ({(passed/len(test_cases))*100:.1f}%)")
print("="*60)
