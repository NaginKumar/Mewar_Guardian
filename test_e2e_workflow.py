import requests
import json
import time
from database.db import get_emergency_by_id, get_emergencies
from config.locations import campus_locations

BASE_URL = "http://127.0.0.1:5000"

def test_backend_e2e():
    print("=" * 60)
    print("MEWAR GUARDIAN - VERIFICATION TEST SUITE")
    print("=" * 60)

    # 1. Health check
    print("\n[TEST 1] Testing /api/health...")
    r = requests.get(f"{BASE_URL}/api/health", timeout=5)
    assert r.status_code == 200, f"Expected 200, got {r.status_code}"
    print("  -> PASSED: Backend is healthy and online.")

    # 2. Campus locations endpoint
    print("\n[TEST 2] Testing /api/locations (All 33 Canonical Locations)...")
    r = requests.get(f"{BASE_URL}/api/locations", timeout=5)
    assert r.status_code == 200, f"Expected 200, got {r.status_code}"
    locs = r.json().get("locations", [])
    assert len(locs) == 33, f"Expected 33 locations, got {len(locs)}"
    loc_names = [l["name"] for l in locs]
    assert "Engineering Block" in loc_names
    assert "Sanga Hostel" in loc_names
    assert "Hospital" in loc_names
    print(f"  -> PASSED: Loaded {len(locs)} canonical campus locations without modification.")

    # 3. Emergency Submission with Manual Campus Location
    print("\n[TEST 3] Submitting SOS with Manual Campus Location ('Engineering Block')...")
    payload1 = {
        "student_name": "Aarav Sharma (DEMO ONLY)",
        "mobile_number": "9000000001",
        "enrollment_number": "DEMO2500001",
        "emergency_type": "Fire",
        "description": "Dense smoke near lab exit on ground floor",
        "location": "Engineering Block",
        "client_request_id": f"test_req_{int(time.time())}"
    }
    r1 = requests.post(f"{BASE_URL}/api/emergency", json=payload1, timeout=8)
    assert r1.status_code == 200, f"Expected 200, got {r1.status_code}: {r1.text}"
    res1 = r1.json()
    assert res1.get("success") is True
    eid1 = res1.get("emergency_id")
    assert eid1 and eid1 > 0
    assert res1.get("location") == "Engineering Block"
    assert res1.get("responder") == "Fire Response Team"
    print(f"  -> PASSED: Emergency #{eid1} accepted by backend with responder '{res1.get('responder')}'.")

    # 4. Verify Database Persistence
    print(f"\n[TEST 4] Verifying MySQL Database Persistence for Emergency #{eid1}...")
    db_row = get_emergency_by_id(eid1)
    assert db_row is not None, f"Emergency #{eid1} not found in database!"
    assert db_row.get("student_name") == "Aarav Sharma (DEMO ONLY)"
    assert db_row.get("location") == "Engineering Block"
    assert db_row.get("emergency_type") == "Fire"
    print(f"  -> PASSED: Emergency #{eid1} successfully verified in MySQL database.")

    # 5. Verify Idempotency (Prevent Duplicate Taps)
    print("\n[TEST 5] Testing Idempotency Protection against double-tap...")
    r1_duplicate = requests.post(f"{BASE_URL}/api/emergency", json=payload1, timeout=8)
    assert r1_duplicate.status_code == 200
    res_dup = r1_duplicate.json()
    assert res_dup.get("emergency_id") == eid1, f"Expected same emergency ID {eid1}, got {res_dup.get('emergency_id')}"
    print(f"  -> PASSED: Duplicate request returned existing Emergency #{eid1} without creating duplicates.")

    # 6. Emergency Submission with GPS Coordinates
    print("\n[TEST 6] Submitting SOS with GPS Coordinates...")
    payload2 = {
        "student_name": "Aarav Sharma (DEMO ONLY)",
        "mobile_number": "9000000001",
        "enrollment_number": "DEMO2500001",
        "emergency_type": "Medical Emergency",
        "description": "Student fainted near sports field",
        "location": "Football Ground",
        "student_lat": 25.03425,
        "student_lon": 74.63725,
        "location_accuracy": 4.5,
        "client_request_id": f"test_req_gps_{int(time.time())}"
    }
    r2 = requests.post(f"{BASE_URL}/api/emergency", json=payload2, timeout=8)
    assert r2.status_code == 200
    res2 = r2.json()
    eid2 = res2.get("emergency_id")
    assert eid2 and eid2 > 0
    assert res2.get("responder") == "Medical Team"
    print(f"  -> PASSED: Emergency #{eid2} accepted with GPS coordinates and dispatched to Medical Team.")

    # 7. Verify Emergency Retrieval via API
    print(f"\n[TEST 7] Fetching Emergency #{eid2} via /api/emergency/{eid2}...")
    r_get = requests.get(f"{BASE_URL}/api/emergency/{eid2}", timeout=5)
    assert r_get.status_code == 200
    get_data = r_get.json()
    assert get_data.get("id") == eid2
    assert get_data.get("location") == "Football Ground"
    print("  -> PASSED: Emergency endpoint returned verified record.")

    print("\n" + "=" * 60)
    print("ALL 7 END-TO-END BACKEND & DATABASE TESTS PASSED!")
    print("=" * 60)

if __name__ == "__main__":
    test_backend_e2e()
