import requests
import json
import sys

BASE_URL = "http://127.0.0.1:5000"

# List of required test questions from user prompt
QUESTIONS = [
    ("Who is your developer?", "English"),
    ("Who created you?", "English"),
    ("Who made you?", "English"),
    ("Tumhara developer kaun hai?", "Hindi"),
    ("Tumhe kisne banaya?", "Hindi"),
    ("Tera creator kaun hai?", "Hinglish"),
    ("Nagin Daksh kaun hai?", "Hindi/Hinglish"),
    ("Who developed Mewar Guardian AI?", "English"),
]

def run_tests():
    print("=" * 70)
    print("MEWAR GUARDIAN AI — DEVELOPER IDENTITY & CREATOR RECOGNITION TESTS")
    print("=" * 70)

    passed = 0
    total = len(QUESTIONS)

    for q, lang in QUESTIONS:
        print(f"\n[QUERY ({lang})]: \"{q}\"")
        try:
            r = requests.post(
                f"{BASE_URL}/api/chat",
                json={"message": q, "history": []},
                timeout=10
            )
            assert r.status_code == 200, f"Expected status 200, got {r.status_code}"
            data = r.json()
            msg = data.get("message", "")
            is_emergency = data.get("is_emergency")

            print(f"  Response: {msg}")
            print(f"  Emergency Flag: {is_emergency}")

            # Verification assertions
            assert "nagin daksh" in msg.lower() or "nagin" in msg.lower(), "Response must mention Nagin Daksh"
            assert is_emergency is False, "Developer query must not be flagged as an emergency"
            assert "mewar guardian" in msg.lower() or "campus safety" in msg.lower(), "Response must mention project context"

            print(f"  -> RESULT: PASSED (Verified developer identity & non-emergency)")
            passed += 1

        except Exception as e:
            print(f"  -> RESULT: FAILED ({e})")

    print("\n" + "=" * 70)
    print(f"TEST SUMMARY: {passed}/{total} Passed ({(passed/total)*100:.1f}%)")
    print("=" * 70)

    return passed == total

if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
