import requests
import json
import time
import secrets

BASE_URL = "http://127.0.0.1:5000"

def run_tests():
    print("=" * 65)
    print("MEWAR GUARDIAN — FORGOT PASSWORD & SMS OTP INTEGRATION TEST SUITE")
    print("=" * 65)

    timestamp = int(time.time())
    test_enrollment = f"MURTEST{timestamp % 100000}"
    test_mobile = f"98{secrets.randbelow(90000000) + 10000000}"
    original_pwd = "InitialSecurePass@2026"
    new_pwd = "NewUpdatedPass#2026"

    # Step 0: Create a test student account directly or via registration
    print(f"\n[SETUP] Creating test student: {test_enrollment} / {test_mobile}...")
    reg_payload = {
        "enrollment": test_enrollment,
        "name": "Integration Test Student",
        "mobile": test_mobile,
        "password": original_pwd,
    }
    r = requests.post(f"{BASE_URL}/api/register", json=reg_payload, timeout=5)
    assert r.status_code == 201, f"Student registration failed: {r.text}"
    print("  -> PASSED: Test student account created successfully.")

    # 1. Verify Login with original password works
    print("\n[TEST 1] Verifying login with original password...")
    login_payload = {"identifier": test_enrollment, "password": original_pwd}
    r = requests.post(f"{BASE_URL}/api/login", json=login_payload, timeout=5)
    assert r.status_code == 200, f"Original login failed: {r.text}"
    assert r.json().get("success") is True
    print("  -> PASSED: Login with original password succeeded.")

    # 2. Unknown account / mismatched mobile anti-enumeration check
    print("\n[TEST 2] Testing generic response on mismatched account/mobile (Anti-enumeration)...")
    fake_payload = {"enrollment_number": "MUR9999999", "mobile_number": "9999999999"}
    r = requests.post(f"{BASE_URL}/api/auth/forgot-password", json=fake_payload, timeout=5)
    assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"
    res = r.json()
    assert res.get("success") is True
    assert "If the account details are valid" in res.get("message", "")
    print("  -> PASSED: Generic message returned without revealing account non-existence.")

    # 3. Valid recovery request generates OTP
    print(f"\n[TEST 3] Initiating valid password recovery for {test_enrollment}...")
    forgot_payload = {"enrollment_number": test_enrollment, "mobile_number": test_mobile}
    r = requests.post(f"{BASE_URL}/api/auth/forgot-password", json=forgot_payload, timeout=5)
    assert r.status_code == 200
    res = r.json()
    assert res.get("success") is True
    # In dev mode, dev_otp is returned for testing inspection
    dev_otp = res.get("dev_otp")
    assert dev_otp is not None and len(dev_otp) == 6, f"Expected 6-digit OTP, got {dev_otp}"
    print(f"  -> PASSED: OTP successfully generated and dispatched (Dev OTP: {dev_otp}).")

    # 4. Incorrect OTP verification is rejected
    print("\n[TEST 4] Testing rejection of incorrect OTP...")
    bad_verify_payload = {"enrollment_number": test_enrollment, "otp": "000000"}
    r = requests.post(f"{BASE_URL}/api/auth/verify-reset-otp", json=bad_verify_payload, timeout=5)
    assert r.status_code == 400
    assert r.json().get("success") is False
    print("  -> PASSED: Incorrect OTP was rejected with HTTP 400.")

    # 5. Correct OTP verification succeeds and returns single-use reset token
    print("\n[TEST 5] Testing verification of correct OTP...")
    good_verify_payload = {"enrollment_number": test_enrollment, "otp": dev_otp}
    r = requests.post(f"{BASE_URL}/api/auth/verify-reset-otp", json=good_verify_payload, timeout=5)
    assert r.status_code == 200
    res = r.json()
    assert res.get("success") is True
    reset_token = res.get("reset_token")
    assert reset_token is not None and len(reset_token) > 20, f"Invalid reset token: {reset_token}"
    print(f"  -> PASSED: Correct OTP accepted. Reset token received (len={len(reset_token)}).")

    # 6. Reusing same OTP fails (cannot verify again)
    print("\n[TEST 6] Testing that used OTP cannot be verified a second time...")
    r = requests.post(f"{BASE_URL}/api/auth/verify-reset-otp", json=good_verify_payload, timeout=5)
    assert r.status_code == 400
    print("  -> PASSED: OTP replay prevented; already used OTP rejected.")

    # 7. Setting password with invalid/forged reset token fails
    print("\n[TEST 7] Testing password reset rejection with fake reset token...")
    fake_reset_payload = {
        "enrollment_number": test_enrollment,
        "reset_token": "fake_token_random_1234567890",
        "new_password": new_pwd,
        "confirm_password": new_pwd
    }
    r = requests.post(f"{BASE_URL}/api/auth/reset-password", json=fake_reset_payload, timeout=5)
    assert r.status_code == 400
    assert r.json().get("success") is False
    print("  -> PASSED: Forged reset token rejected with HTTP 400.")

    # 8. Setting password with mismatched passwords fails
    print("\n[TEST 8] Testing validation when new_password != confirm_password...")
    mismatch_payload = {
        "enrollment_number": test_enrollment,
        "reset_token": reset_token,
        "new_password": new_pwd,
        "confirm_password": "CompletelyDifferentPassword999"
    }
    r = requests.post(f"{BASE_URL}/api/auth/reset-password", json=mismatch_payload, timeout=5)
    assert r.status_code == 400
    print("  -> PASSED: Password mismatch rejected.")

    # 9. Successful password reset with valid authorization token
    print("\n[TEST 9] Resetting password with valid reset token...")
    valid_reset_payload = {
        "enrollment_number": test_enrollment,
        "reset_token": reset_token,
        "new_password": new_pwd,
        "confirm_password": new_pwd
    }
    r = requests.post(f"{BASE_URL}/api/auth/reset-password", json=valid_reset_payload, timeout=5)
    assert r.status_code == 200
    assert r.json().get("success") is True
    print("  -> PASSED: Password reset successfully committed.")

    # 10. Reusing consumed reset token fails
    print("\n[TEST 10] Testing that consumed reset token cannot be reused...")
    r = requests.post(f"{BASE_URL}/api/auth/reset-password", json=valid_reset_payload, timeout=5)
    assert r.status_code == 400
    assert r.json().get("success") is False
    print("  -> PASSED: Consumed reset token cannot be reused.")

    # 11. Old password NO LONGER works
    print("\n[TEST 11] Verifying that OLD password no longer works for login...")
    old_login = {"identifier": test_enrollment, "password": original_pwd}
    r = requests.post(f"{BASE_URL}/api/login", json=old_login, timeout=5)
    assert r.status_code == 401
    assert r.json().get("success") is False
    print("  -> PASSED: Old password rejected with 401 Unauthorized.")

    # 12. NEW password works
    print("\n[TEST 12] Verifying that NEW password successfully logs in...")
    new_login = {"identifier": test_enrollment, "password": new_pwd}
    r = requests.post(f"{BASE_URL}/api/login", json=new_login, timeout=5)
    assert r.status_code == 200
    assert r.json().get("success") is True
    assert r.json().get("student", {}).get("enrollment_number") == test_enrollment
    print("  -> PASSED: Login with new password succeeded!")

    print("\n" + "=" * 65)
    print("ALL 12 FORGOT PASSWORD & SMS OTP VERIFICATION TESTS PASSED!")
    print("=" * 65)

if __name__ == "__main__":
    run_tests()
