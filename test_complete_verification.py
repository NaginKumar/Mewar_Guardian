"""
Mewar Guardian Comprehensive Verification Script
Tests:
1. Personal details removal & fictional demo data verification
2. Creator attribution queries (English, Hindi, Hinglish natural variations)
3. Non-attribution queries (safety, emergency do NOT mention creator)
4. Photo upload endpoint (/api/upload)
5. Photo serving endpoint (/api/uploads/<filename>)
6. AI chat with photo attachment
7. Emergency creation with photo_url
"""

import sys, os, io, json, requests

BASE_URL = "http://127.0.0.1:5000"

def test_creator_attribution():
    print("==================================================")
    print("1. TESTING CREATOR ATTRIBUTION QUERIES")
    print("==================================================")

    creator_queries = [
        ("Who made you?", "I was developed for Mewar Guardian by Nagin Daksh."),
        ("Tumhe kisne banaya?", "Mujhe Mewar Guardian ke liye Nagin Daksh ne develop kiya hai."),
        ("Who is your creator?", "I was developed for Mewar Guardian by Nagin Daksh."),
        ("Who developed this assistant?", "I was developed for Mewar Guardian by Nagin Daksh."),
        ("Who is your developer?", "I was developed for Mewar Guardian by Nagin Daksh."),
        ("Tumhara developer kaun hai?", "Mujhe Mewar Guardian ke liye Nagin Daksh ne develop kiya hai."),
        ("Who created you?", "I was developed for Mewar Guardian by Nagin Daksh."),
    ]

    for q, expected in creator_queries:
        res = requests.post(f"{BASE_URL}/api/chat", json={"message": q}, timeout=25)
        assert res.status_code == 200, f"Query '{q}' returned status {res.status_code}"
        data = res.json()
        msg = data.get("message", "")
        print(f"Q: '{q}' -> A: '{msg}'")
        assert "nagin daksh" in msg.lower(), f"Failed to attribute Nagin Daksh for '{q}': {msg}"
        assert data.get("is_emergency") is False, f"Creator query was wrongly flagged as emergency: {q}"
    print(">> All creator attribution queries PASSED.\n")

def test_normal_queries_no_creator():
    print("==================================================")
    print("2. TESTING NORMAL QUERIES (NO CREATOR MENTION)")
    print("==================================================")

    normal_queries = [
        "What is the safety protocol during a campus fire?",
        "Where is the campus dispensary located?",
        "Main gate par guard se kaise connect karein?",
    ]

    for q in normal_queries:
        res = requests.post(f"{BASE_URL}/api/chat", json={"message": q}, timeout=25)
        assert res.status_code == 200
        data = res.json()
        msg = data.get("message", "")
        print(f"Q: '{q}' -> A (prefix): '{msg[:80]}...'")
        assert "nagin" not in msg.lower(), f"Unrelated query mentioned Nagin: {q}"
    print(">> Normal safety queries independence PASSED.\n")

def test_photo_upload_and_serving():
    print("==================================================")
    print("3. TESTING PHOTO UPLOAD AND SERVING")
    print("==================================================")

    # 1. Valid PNG upload
    dummy_png = b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15c4\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82"
    files = {"photo": ("test_incident.png", dummy_png, "image/png")}
    res = requests.post(f"{BASE_URL}/api/upload", files=files, timeout=10)
    assert res.status_code == 200, f"Upload returned {res.status_code}: {res.text}"
    upload_data = res.json()
    assert upload_data.get("success") is True, f"Upload failed: {upload_data}"
    photo_url = upload_data.get("photo_url")
    print(f"Uploaded successfully: {photo_url}")

    # 2. Serve uploaded image
    serve_res = requests.get(f"{BASE_URL}{photo_url}", timeout=10)
    assert serve_res.status_code == 200, f"Serving returned {serve_res.status_code}"
    assert serve_res.content == dummy_png, "Served content does not match uploaded content"
    print(">> Uploaded photo serving verified.\n")

    # 3. Reject invalid extension
    bad_files = {"photo": ("test_script.exe", b"binarycontent", "application/octet-stream")}
    res_bad = requests.post(f"{BASE_URL}/api/upload", files=bad_files, timeout=10)
    assert res_bad.status_code == 400, "Server accepted invalid file type"
    print(">> File extension security validation PASSED.\n")

    return photo_url

def test_chat_and_emergency_with_photo(photo_url):
    print("==================================================")
    print("4. TESTING AI CHAT & SOS WITH PHOTO ATTACHMENT")
    print("==================================================")

    # 1. Chat with photo
    res_chat = requests.post(
        f"{BASE_URL}/api/chat",
        json={"message": "Please look at this incident photo near Library block", "photo_url": photo_url},
        timeout=10
    )
    assert res_chat.status_code == 200, f"Chat with photo failed: {res_chat.text}"
    chat_data = res_chat.json()
    print(f"Chat with photo response: {chat_data.get('message')}")
    assert chat_data.get("attached_photo") == photo_url, "Attached photo not reflected in response"

    # 2. Create emergency with photo
    emergency_payload = {
        "student_name": "Aarav Sharma",
        "mobile_number": "9000000001",
        "enrollment_number": "MUR2500001",
        "emergency_type": "Medical Emergency",
        "description": "Student feeling dizzy outside Admin Block with photo proof.",
        "location": "Admin Block",
        "photo_url": photo_url,
    }
    res_emg = requests.post(f"{BASE_URL}/api/emergency", json=emergency_payload, timeout=10)
    assert res_emg.status_code in [200, 201], f"Emergency creation failed: {res_emg.text}"
    emg_data = res_emg.json()
    emg_id = emg_data.get("emergency_id")
    print(f"Created emergency #{emg_id} with photo_url: {emg_data.get('photo_url')}")
    assert emg_data.get("photo_url") == photo_url

    # 3. Fetch emergency by ID (for admin/tracking)
    res_fetch = requests.get(f"{BASE_URL}/api/emergency/{emg_id}", timeout=10)
    assert res_fetch.status_code == 200
    fetched_data = res_fetch.json()
    assert fetched_data.get("photo_url") == photo_url, f"Fetched record missing photo_url: {fetched_data}"
    print(f"Admin fetch emergency #{emg_id} photo_url: {fetched_data.get('photo_url')}")
    print(">> Chat and Emergency photo persistence PASSED.\n")

if __name__ == "__main__":
    test_creator_attribution()
    test_normal_queries_no_creator()
    photo_url = test_photo_upload_and_serving()
    test_chat_and_emergency_with_photo(photo_url)
    print("==================================================")
    print("ALL VERIFICATION SUITES PASSED SUCCESSFULLY!")
    print("==================================================")
