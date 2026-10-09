import os
import requests
import logging

logger = logging.getLogger("sms_service")

# Real SMS Providers supported:
# 1. Twilio: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER
# 2. Fast2SMS: FAST2SMS_API_KEY
# 3. MSG91: MSG91_AUTH_KEY, MSG91_TEMPLATE_ID

def is_sms_configured() -> bool:
    """Return True if any production SMS gateway is configured with credentials."""
    twilio_ready = bool(os.getenv("TWILIO_ACCOUNT_SID") and os.getenv("TWILIO_AUTH_TOKEN") and os.getenv("TWILIO_PHONE_NUMBER"))
    fast2sms_ready = bool(os.getenv("FAST2SMS_API_KEY"))
    msg91_ready = bool(os.getenv("MSG91_AUTH_KEY"))
    return twilio_ready or fast2sms_ready or msg91_ready

def get_configured_provider_name() -> str:
    if os.getenv("TWILIO_ACCOUNT_SID") and os.getenv("TWILIO_AUTH_TOKEN"):
        return "Twilio"
    if os.getenv("FAST2SMS_API_KEY"):
        return "Fast2SMS"
    if os.getenv("MSG91_AUTH_KEY"):
        return "MSG91"
    return "None (Dev Simulator Active)"

def mask_mobile(mobile: str) -> str:
    m = str(mobile).strip()
    if len(m) >= 10:
        return f"{m[:2]}••••••{m[-2:]}"
    return m

def send_otp_sms(mobile_number: str, otp: str) -> tuple[bool, str]:
    """
    Send OTP via configured real SMS provider.
    Returns (success: bool, status_message: str).
    """
    mobile = str(mobile_number).strip().replace(" ", "").replace("-", "")
    masked = mask_mobile(mobile)

    # 1. Try Twilio
    twilio_sid = os.getenv("TWILIO_ACCOUNT_SID")
    twilio_token = os.getenv("TWILIO_AUTH_TOKEN")
    twilio_from = os.getenv("TWILIO_PHONE_NUMBER")
    if twilio_sid and twilio_token and twilio_from:
        try:
            # Normalize E.164
            to_number = mobile if mobile.startswith("+") else f"+91{mobile}" if len(mobile) == 10 else f"+{mobile}"
            url = f"https://api.twilio.com/2010-04-01/Accounts/{twilio_sid}/Messages.json"
            msg = f"Your Mewar Guardian verification code is {otp}. Valid for 5 minutes. Do not share this code with anyone."
            resp = requests.post(
                url,
                auth=(twilio_sid, twilio_token),
                data={"To": to_number, "From": twilio_from, "Body": msg},
                timeout=8
            )
            if resp.status_code in (200, 201):
                logger.info(f"[SMS Gateway: Twilio] OTP successfully dispatched to {masked}")
                return True, "OTP successfully sent to your registered mobile number."
            else:
                logger.error(f"[SMS Gateway: Twilio Error] Status {resp.status_code}: {resp.text}")
                return False, f"SMS gateway error: {resp.status_code}"
        except Exception as e:
            logger.error(f"[SMS Gateway: Twilio Exception] {e}")
            return False, "Failed to connect to SMS delivery gateway."

    # 2. Try Fast2SMS (Indian SMS Gateway)
    fast2sms_key = os.getenv("FAST2SMS_API_KEY")
    if fast2sms_key:
        try:
            clean_10 = mobile[-10:] if len(mobile) >= 10 else mobile
            url = "https://www.fast2sms.com/dev/bulkV2"
            headers = {"authorization": fast2sms_key}
            payload = {
                "variables_values": otp,
                "route": "otp",
                "numbers": clean_10
            }
            resp = requests.post(url, headers=headers, json=payload, timeout=8)
            res_data = resp.json()
            if res_data.get("return") is True:
                logger.info(f"[SMS Gateway: Fast2SMS] OTP successfully dispatched to {masked}")
                return True, "OTP successfully sent to your registered mobile number."
            else:
                logger.error(f"[SMS Gateway: Fast2SMS Error] {res_data.get('message')}")
                return False, f"SMS gateway error: {res_data.get('message', 'Delivery failed')}"
        except Exception as e:
            logger.error(f"[SMS Gateway: Fast2SMS Exception] {e}")
            return False, "Failed to connect to Fast2SMS gateway."

    # 3. Try MSG91
    msg91_key = os.getenv("MSG91_AUTH_KEY")
    if msg91_key:
        try:
            clean_10 = mobile[-10:] if len(mobile) >= 10 else mobile
            template_id = os.getenv("MSG91_TEMPLATE_ID", "")
            url = f"https://control.msg91.com/api/v5/otp?template_id={template_id}&mobile=91{clean_10}&authkey={msg91_key}&otp={otp}"
            resp = requests.post(url, timeout=8)
            res_data = resp.json()
            if res_data.get("type") == "success":
                logger.info(f"[SMS Gateway: MSG91] OTP successfully dispatched to {masked}")
                return True, "OTP successfully sent to your registered mobile number."
            else:
                logger.error(f"[SMS Gateway: MSG91 Error] {res_data.get('message')}")
                return False, f"SMS gateway error: {res_data.get('message')}"
        except Exception as e:
            logger.error(f"[SMS Gateway: MSG91 Exception] {e}")
            return False, "Failed to connect to MSG91 gateway."

    # 4. If No SMS credentials configured
    is_prod = os.getenv("FLASK_ENV") == "production" or os.getenv("RENDER") == "true"
    if is_prod:
        logger.warning(
            f"[SMS Gateway: Unconfigured] No SMS provider credentials (TWILIO_*, FAST2SMS_*, MSG91_*) in environment. "
            f"Cannot send real SMS in production."
        )
        return False, "SMS service is not currently configured on the production server. Please contact university security administration."
    else:
        # Development / Testing Mode
        print("=" * 65)
        print("  [SMS DEV SIMULATOR] REAL SMS CREDENTIALS MISSING")
        print(f"  Target Mobile : {masked} (Registered)")
        print(f"  Generated OTP : {otp}  (Valid for 5 minutes)")
        print("  Configure TWILIO_ACCOUNT_SID or FAST2SMS_API_KEY in .env for live SMS.")
        print("=" * 65)
        return True, "OTP generated and logged to development console (Configure SMS provider for live carrier delivery)."
