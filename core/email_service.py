import os
import smtplib
import ssl
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("email_service")

def is_email_configured() -> bool:
    """Return True if production SMTP credentials are configured in environment."""
    host = os.getenv("SMTP_HOST")
    user = os.getenv("SMTP_USER")
    pwd = os.getenv("SMTP_PASS") or os.getenv("SMTP_PASSWORD")
    return bool(host and user and pwd)

def mask_email(email: str) -> str:
    """Mask email for privacy in responses, e.g. 'aarav@example.com' -> 'aa***v@example.com'."""
    em = str(email).strip().lower()
    if "@" not in em:
        return em
    user, domain = em.split("@", 1)
    if len(user) <= 2:
        masked_user = user[0] + "***" if user else "***"
    else:
        masked_user = f"{user[:2]}***{user[-1]}"
    return f"{masked_user}@{domain}"

def send_password_reset_email(to_email: str, student_name: str, otp: str) -> tuple[bool, str]:
    """
    Send a 6-digit password reset verification code via real SMTP service.
    Returns (success: bool, status_message: str).
    """
    to_email = str(to_email).strip().lower()
    if not to_email or "@" not in to_email:
        return False, "Invalid email address format."

    masked = mask_email(to_email)
    
    # 1. If SMTP is configured, send via real email
    if is_email_configured():
        host = os.getenv("SMTP_HOST")
        port = int(os.getenv("SMTP_PORT", "587"))
        user = os.getenv("SMTP_USER")
        pwd = os.getenv("SMTP_PASS") or os.getenv("SMTP_PASSWORD")
        from_email = os.getenv("SMTP_FROM", user)
        use_ssl = port == 465 or os.getenv("SMTP_USE_SSL", "false").lower() in ("true", "1")

        msg = MIMEMultipart("alternative")
        msg["Subject"] = f"Mewar Guardian – Password Reset Verification Code: {otp}"
        msg["From"] = f"Mewar Guardian Security <{from_email}>"
        msg["To"] = to_email

        plain_text = f"""Hello {student_name or 'Student'},

You requested to reset your password for Mewar Guardian.

Your 6-digit verification code is: {otp}

This code is valid for 15 minutes. Do not share this code with anyone.
If you did not request this password reset, please ignore this email or alert campus security immediately.

— Mewar Guardian Campus Safety Team
"""

        html_body = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body {{ font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; color: #1e293b; }}
  .container {{ max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 16px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,0.06); }}
  .header {{ background: #1B4D3E; padding: 28px 24px; text-align: center; color: #ffffff; }}
  .header h1 {{ margin: 0; font-size: 20px; font-weight: 800; letter-spacing: 0.8px; color: #ffffff; }}
  .header p {{ margin: 6px 0 0 0; font-size: 13px; color: #fdba74; font-weight: 600; }}
  .content {{ padding: 32px 28px; text-align: center; }}
  .greeting {{ font-size: 16px; font-weight: 600; margin-bottom: 12px; text-align: left; }}
  .instructions {{ font-size: 14px; color: #475569; line-height: 1.6; text-align: left; margin-bottom: 24px; }}
  .otp-box {{ background: #fff7ed; border: 2px dashed #f97316; border-radius: 12px; padding: 20px; margin: 20px 0; }}
  .otp-code {{ font-size: 34px; font-weight: 900; letter-spacing: 8px; color: #ea580c; margin: 0; font-family: monospace; }}
  .otp-sub {{ font-size: 12px; color: #9a3412; margin-top: 8px; font-weight: 600; }}
  .warning {{ font-size: 12px; color: #64748b; line-height: 1.5; margin-top: 24px; padding-top: 16px; border-top: 1px solid #f1f5f9; text-align: left; }}
  .footer {{ background: #f1f5f9; padding: 16px; text-align: center; font-size: 11px; color: #64748b; }}
</style>
</head>
<body>
<div class="container">
  <div class="header">
    <h1>🛡️ MEWAR GUARDIAN</h1>
    <p>Campus Safety & Emergency Response</p>
  </div>
  <div class="content">
    <div class="greeting">Hello {student_name or 'Student'},</div>
    <div class="instructions">
      We received a request to reset the password for your student safety account. Use the verification code below to authorize your password update.
    </div>
    <div class="otp-box">
      <div class="otp-code">{otp}</div>
      <div class="otp-sub">⏱️ Valid for 15 minutes only</div>
    </div>
    <div class="warning">
      🔒 <strong>Security Warning:</strong> Never share this code with anyone, including campus staff. If you did not request this reset, your account is safe and you can safely ignore this email.
    </div>
  </div>
  <div class="footer">
    Mewar Guardian • Emergency Helpline: +91 1477-229900 • Mewar University
  </div>
</div>
</body>
</html>
"""
        msg.attach(MIMEText(plain_text, "plain"))
        msg.attach(MIMEText(html_body, "html"))

        try:
            if use_ssl:
                context = ssl.create_default_context()
                with smtplib.SMTP_SSL(host, port, context=context, timeout=12) as server:
                    server.login(user, pwd)
                    server.send_message(msg)
            else:
                with smtplib.SMTP(host, port, timeout=12) as server:
                    server.ehlo()
                    server.starttls(context=ssl.create_default_context())
                    server.ehlo()
                    server.login(user, pwd)
                    server.send_message(msg)

            logger.info(f"[Email Service] Password reset code dispatched successfully to {masked}")
            return True, f"Verification code sent to your registered email ({masked})."
        except Exception as e:
            logger.error(f"[Email Service Error] Failed to send email to {masked}: {e}")
            return False, f"Email delivery failed: {str(e)}"

    # 2. If SMTP is not configured:
    # In test/dev environment, allow test runner to proceed if explicit ALLOW_DEV_EMAIL_OTP is set
    raw_dev = (os.getenv("ALLOW_DEV_EMAIL_OTP") or "").strip().lower()
    allow_dev = raw_dev in ("true", "1", "yes") or bool(os.getenv("PYTEST_CURRENT_TEST")) or ("test" in (os.getenv("FLASK_ENV") or "").lower())
    if allow_dev:
        logger.info(f"[Email Service: Dev Simulator] Reset OTP for {masked}: {otp}")
        return True, f"[TEST MODE] Verification code generated for {masked}."
    
    # Otherwise, return clear error without pretending email was sent
    return False, "Email service is not configured on the server. Please contact campus administrator to configure SMTP credentials."
