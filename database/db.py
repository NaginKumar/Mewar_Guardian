import pymysql
import sqlite3
import pandas as pd
from datetime import datetime, timedelta
import os
import secrets
import hashlib
from core.sms_service import send_otp_sms

DB_HOST = os.getenv("MYSQL_HOST", "localhost")
DB_USER = os.getenv("MYSQL_USER", "root")
DB_PASS = os.getenv("MYSQL_PASS", "")
DB_NAME = os.getenv("MYSQL_DB", "rakshak_ai")
DB_PORT = int(os.getenv("MYSQL_PORT", "3306"))

SQLITE_PATH = os.getenv(
    "SQLITE_PATH",
    "/var/data/emergencies.db" if os.path.exists("/var/data") else os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "emergencies.db"))
)

class SQLiteCursorWrapper:
    def __init__(self, cursor):
        self._cur = cursor

    def execute(self, sql, params=None):
        sqlite_sql = sql.replace('%s', '?')
        if params is None:
            return self._cur.execute(sqlite_sql)
        if not isinstance(params, (tuple, list)):
            params = (params,)
        return self._cur.execute(sqlite_sql, params)

    def executemany(self, sql, seq_of_params):
        sqlite_sql = sql.replace('%s', '?')
        return self._cur.executemany(sqlite_sql, seq_of_params)

    def fetchone(self):
        r = self._cur.fetchone()
        return dict(r) if r is not None else None

    def fetchall(self):
        rows = self._cur.fetchall()
        return [dict(r) for r in rows] if rows else []

    @property
    def lastrowid(self):
        return self._cur.lastrowid

    def __getattr__(self, name):
        return getattr(self._cur, name)

class SQLiteConnWrapper:
    def __init__(self, conn):
        self._conn = conn
        self.is_sqlite = True

    def cursor(self, *args, **kwargs):
        return SQLiteCursorWrapper(self._conn.cursor())

    def commit(self):
        self._conn.commit()

    def close(self):
        self._conn.close()

    def __getattr__(self, name):
        return getattr(self._conn, name)

def get_connection(include_db=True):
    """
    Connect to MySQL if configured and reachable;
    fallback smoothly to SQLite (emergencies.db) if MySQL is unavailable or unconfigured.
    """
    force_sqlite = os.getenv("USE_SQLITE", "false").lower() in ("true", "1", "yes")
    if DB_HOST and not force_sqlite:
        try:
            if include_db:
                conn = pymysql.connect(
                    host=DB_HOST,
                    user=DB_USER,
                    password=DB_PASS,
                    database=DB_NAME,
                    port=DB_PORT,
                    connect_timeout=3,
                    cursorclass=pymysql.cursors.DictCursor
                )
            else:
                conn = pymysql.connect(
                    host=DB_HOST,
                    user=DB_USER,
                    password=DB_PASS,
                    port=DB_PORT,
                    connect_timeout=3,
                    cursorclass=pymysql.cursors.DictCursor
                )
            conn.is_sqlite = False
            return conn
        except Exception as e:
            print(f"[Database Notice] MySQL ({DB_HOST}) connection failed: {e}. Using SQLite fallback.")

    # Guaranteed fallback to SQLite
    try:
        os.makedirs(os.path.dirname(SQLITE_PATH), exist_ok=True)
        raw_conn = sqlite3.connect(SQLITE_PATH, timeout=30.0, check_same_thread=False)
        raw_conn.row_factory = sqlite3.Row
        return SQLiteConnWrapper(raw_conn)
    except Exception as e:
        print(f"[SQLite Error] Could not connect to SQLite at {SQLITE_PATH}: {e}")
        return None

# =========================================================
# CREATE / MIGRATE SCHEMA
# =========================================================

def create_database():
    """Create the emergencies table if it does not already exist."""
    conn = get_connection(include_db=True)
    if not conn: return
    cursor = conn.cursor()

    if getattr(conn, 'is_sqlite', False):
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS emergencies (
                id                INTEGER PRIMARY KEY AUTOINCREMENT,
                student_name      TEXT,
                mobile_number     TEXT,
                enrollment_number TEXT,
                emergency_type    TEXT,
                location          TEXT,
                description       TEXT,
                priority          TEXT,
                time              TEXT,
                reported_time     TEXT,
                status            TEXT,
                responder         TEXT,
                distance          REAL,
                dispatch_time     TEXT,
                arrived_time      TEXT,
                resolved_time     TEXT,
                on_way_time       TEXT,
                ai_confidence     REAL,
                risk_score        INTEGER,
                recommendation    TEXT,
                estimated_minutes INTEGER,
                student_lat       REAL,
                student_lon       REAL,
                location_accuracy REAL,
                responder_lat     REAL,
                responder_lon     REAL,
                photo_url         TEXT
            )
        """)
    else:
        try:
            conn_admin = get_connection(include_db=False)
            if conn_admin:
                c = conn_admin.cursor()
                c.execute(f"CREATE DATABASE IF NOT EXISTS {DB_NAME}")
                conn_admin.commit()
                conn_admin.close()
        except Exception:
            pass

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS emergencies (
                id                INTEGER PRIMARY KEY AUTO_INCREMENT,
                student_name      TEXT,
                mobile_number     TEXT,
                enrollment_number TEXT,
                emergency_type    TEXT,
                location          TEXT,
                description       TEXT,
                priority          TEXT,
                time              TEXT,
                reported_time     TEXT,
                status            TEXT,
                responder         TEXT,
                distance          REAL,
                dispatch_time     TEXT,
                arrived_time      TEXT,
                resolved_time     TEXT,
                on_way_time       TEXT,
                ai_confidence     REAL,
                risk_score        INTEGER,
                recommendation    TEXT,
                estimated_minutes INTEGER,
                student_lat       REAL,
                student_lon       REAL,
                location_accuracy REAL,
                responder_lat     REAL,
                responder_lon     REAL,
                photo_url         TEXT
            )
        """)

    conn.commit()
    conn.close()


from werkzeug.security import generate_password_hash, check_password_hash

def create_students_table():
    """Create the students table to store profile details."""
    conn = get_connection(include_db=True)
    if not conn: return
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS students (
            enrollment_number VARCHAR(100) PRIMARY KEY,
            student_name      VARCHAR(255),
            mobile_number     VARCHAR(20),
            password_hash     VARCHAR(255),
            role              VARCHAR(50) DEFAULT 'Student',
            registered_at     DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()


def create_password_resets_table():
    """Create the password_resets table to store hashed OTPs and short-lived reset tokens."""
    conn = get_connection(include_db=True)
    if not conn: return
    cursor = conn.cursor()

    if getattr(conn, 'is_sqlite', False):
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS password_resets (
                id                INTEGER PRIMARY KEY AUTOINCREMENT,
                enrollment_number VARCHAR(100) NOT NULL,
                mobile_number     VARCHAR(20) NOT NULL,
                otp_hash          VARCHAR(255) NOT NULL,
                otp_expires_at    DATETIME NOT NULL,
                otp_attempts      INTEGER DEFAULT 0,
                is_verified       BOOLEAN DEFAULT 0,
                reset_token       VARCHAR(255) NULL,
                token_expires_at  DATETIME NULL,
                is_used           BOOLEAN DEFAULT 0,
                created_at        DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_pw_enrollment ON password_resets (enrollment_number)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_pw_reset_token ON password_resets (reset_token)")
    else:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS password_resets (
                id                INTEGER PRIMARY KEY AUTO_INCREMENT,
                enrollment_number VARCHAR(100) NOT NULL,
                mobile_number     VARCHAR(20) NOT NULL,
                otp_hash          VARCHAR(255) NOT NULL,
                otp_expires_at    DATETIME NOT NULL,
                otp_attempts      INTEGER DEFAULT 0,
                is_verified       BOOLEAN DEFAULT FALSE,
                reset_token       VARCHAR(255) NULL,
                token_expires_at  DATETIME NULL,
                is_used           BOOLEAN DEFAULT FALSE,
                created_at        DATETIME DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_enrollment (enrollment_number),
                INDEX idx_reset_token (reset_token)
            )
        """)

    conn.commit()
    conn.close()


def add_missing_columns():
    """Safely add any columns that may be missing from older database files."""
    conn = get_connection()
    if not conn: return
    cursor = conn.cursor()

    is_sqlite = getattr(conn, 'is_sqlite', False)
    if is_sqlite:
        cursor.execute("PRAGMA table_info(emergencies)")
        columns = [row['name'] for row in cursor.fetchall()]
    else:
        cursor.execute("SHOW COLUMNS FROM emergencies")
        columns = [row['Field'] for row in cursor.fetchall()]

    new_columns = {
        "mobile_number":     "TEXT",
        "enrollment_number": "TEXT",
        "priority":          "TEXT",
        "reported_time":     "TEXT",
        "responder":         "TEXT",
        "distance":          "REAL",
        "dispatch_time":     "TEXT",
        "arrived_time":      "TEXT",
        "resolved_time":     "TEXT",
        "on_way_time":       "TEXT",
        "ai_confidence":     "REAL",
        "risk_score":        "INTEGER",
        "recommendation":    "TEXT",
        "estimated_minutes": "INTEGER",
        "student_lat":       "REAL",
        "student_lon":       "REAL",
        "location_accuracy": "REAL",
        "responder_lat":     "REAL",
        "responder_lon":     "REAL",
        "photo_url":         "TEXT",
    }

    for col, col_type in new_columns.items():
        if col not in columns:
            cursor.execute(f"ALTER TABLE emergencies ADD COLUMN {col} {col_type}")

    # 2. Update students columns
    try:
        if is_sqlite:
            cursor.execute("PRAGMA table_info(students)")
            student_cols = [row['name'] for row in cursor.fetchall()]
        else:
            cursor.execute("SHOW COLUMNS FROM students")
            student_cols = [row['Field'] for row in cursor.fetchall()]

        if "password_hash" not in student_cols:
            cursor.execute("ALTER TABLE students ADD COLUMN password_hash VARCHAR(255)")
        if "role" not in student_cols:
            cursor.execute("ALTER TABLE students ADD COLUMN role VARCHAR(50) DEFAULT 'Student'")
    except Exception as e:
        print(f"[students column migration] {e}")

    conn.commit()
    conn.close()


# =========================================================
# CRUD OPERATIONS
# =========================================================

def add_emergency(
    student_name: str,
    emergency_type: str,
    location: str,
    description: str,
    priority: str,
    responder: str,
    distance: float,
    ai_confidence: float,
    risk_score: int,
    recommendation: str,
    estimated_minutes: int,
    student_lat=None,
    student_lon=None,
    mobile_number=None,
    enrollment_number=None,
    location_accuracy=None,
    responder_lat=None,
    responder_lon=None,
    photo_url=None
) -> int:
    """Insert a new emergency record and return its auto-generated ID."""
    conn = get_connection()
    if not conn: return 0
    cursor = conn.cursor()

    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    cursor.execute("""
        INSERT INTO emergencies (
            student_name, mobile_number, enrollment_number, emergency_type, location, description,
            priority, time, reported_time, status, responder, distance,
            ai_confidence, risk_score, recommendation, estimated_minutes,
            student_lat, student_lon, location_accuracy, responder_lat, responder_lon, photo_url
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """, (
        student_name, mobile_number, enrollment_number, emergency_type, location, description,
        priority, now_str, now_str, "Pending", responder, distance,
        ai_confidence, risk_score, recommendation, estimated_minutes,
        student_lat, student_lon, location_accuracy, responder_lat, responder_lon, photo_url
    ))

    emergency_id = cursor.lastrowid
    conn.commit()
    conn.close()
    return emergency_id


def save_student_profile(enrollment: str, name: str, mobile: str) -> bool:
    """Upsert student profile into the students table."""
    conn = get_connection()
    if not conn: return False
    cursor = conn.cursor()
    try:
        if getattr(conn, 'is_sqlite', False):
            cursor.execute("""
                INSERT INTO students (enrollment_number, student_name, mobile_number)
                VALUES (%s, %s, %s)
                ON CONFLICT(enrollment_number) DO UPDATE SET student_name=excluded.student_name, mobile_number=excluded.mobile_number
            """, (enrollment, name, mobile))
        else:
            cursor.execute("""
                INSERT INTO students (enrollment_number, student_name, mobile_number)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE student_name=%s, mobile_number=%s
            """, (enrollment, name, mobile, name, mobile))
        conn.commit()
        return True
    except Exception as e:
        print(f"[Save Student Profile Error] {e}")
        return False
    finally:
        conn.close()


def register_student(enrollment: str, name: str, mobile: str, password: str) -> tuple[bool, str]:
    """Register a new student with salted password hash and role='Student'."""
    enrollment = str(enrollment).strip().upper()
    name = str(name).strip()
    mobile = str(mobile).strip()
    password = str(password).strip()

    if not name or len(name) < 2:
        return False, "Full name must be at least 2 characters."
    if not mobile or len(mobile) != 10 or not mobile.isdigit():
        return False, "Valid 10-digit mobile number is required."
    if not enrollment or not enrollment.startswith("MUR") or len(enrollment) < 5:
        return False, "Enrollment number must start with MUR (e.g., MUR2500001)."
    if not password or len(password) < 4:
        return False, "Password must be at least 4 characters long."

    conn = get_connection()
    if not conn:
        return False, "Database connection error."

    cursor = conn.cursor(pymysql.cursors.DictCursor)
    try:
        cursor.execute("SELECT enrollment_number FROM students WHERE enrollment_number = %s", (enrollment,))
        if cursor.fetchone():
            return False, "An account with this enrollment number already exists."

        cursor.execute("SELECT enrollment_number FROM students WHERE mobile_number = %s", (mobile,))
        if cursor.fetchone():
            return False, "An account with this mobile number already exists."

        pwd_hash = generate_password_hash(password)

        cursor.execute("""
            INSERT INTO students (enrollment_number, student_name, mobile_number, password_hash, role)
            VALUES (%s, %s, %s, %s, 'Student')
        """, (enrollment, name, mobile, pwd_hash))
        conn.commit()
        return True, "Student registered successfully."
    except Exception as e:
        print(f"[MySQL Register Error] {e}")
        return False, f"Failed to register account: {e}"
    finally:
        conn.close()


def authenticate_student(identifier: str, password: str) -> dict | None:
    """Verify credentials for student login; returns student profile dict or None."""
    ident = str(identifier).strip()
    pwd = str(password).strip()
    if not ident or not pwd:
        return None

    conn = get_connection()
    if not conn:
        return None

    cursor = conn.cursor(pymysql.cursors.DictCursor)
    try:
        cursor.execute("""
            SELECT enrollment_number, student_name, mobile_number, password_hash, role
            FROM students
            WHERE enrollment_number = %s OR mobile_number = %s
        """, (ident.upper(), ident))
        row = cursor.fetchone()
        if not row:
            return None

        stored_hash = row.get("password_hash")
        if stored_hash and check_password_hash(stored_hash, pwd):
            return {
                "enrollment_number": row["enrollment_number"],
                "student_name": row["student_name"],
                "mobile_number": row["mobile_number"],
                "role": row.get("role", "Student")
            }
        return None
    except Exception as e:
        print(f"[MySQL Auth Error] {e}")
        return None
    finally:
        conn.close()


def get_student_profile(enrollment: str) -> dict | None:
    """Retrieve public profile for a verified student."""
    conn = get_connection()
    if not conn: return None
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    try:
        cursor.execute("""
            SELECT enrollment_number, student_name, mobile_number, role, registered_at
            FROM students WHERE enrollment_number = %s
        """, (enrollment.upper(),))
        row = cursor.fetchone()
        if not row: return None
        if "registered_at" in row and row["registered_at"]:
            row["registered_at"] = str(row["registered_at"])
        return dict(row)
    finally:
        conn.close()


def get_student_emergencies(enrollment_or_mobile: str) -> list[dict]:
    """Retrieve submitted emergency records for this student."""
    ident = str(enrollment_or_mobile).strip()
    conn = get_connection()
    if not conn: return []
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    try:
        cursor.execute("""
            SELECT id, emergency_type, location, description, priority, status, time,
                   responder, estimated_minutes, recommendation, photo_url
            FROM emergencies
            WHERE enrollment_number = %s OR mobile_number = %s
            ORDER BY id DESC LIMIT 50
        """, (ident.upper(), ident))
        rows = cursor.fetchall()
        return [dict(r) for r in rows] if rows else []
    except Exception as e:
        print(f"[MySQL Student Emergencies Error] {e}")
        return []
    finally:
        conn.close()


def delete_student_account(enrollment: str, password: str) -> tuple[bool, str]:
    """Securely delete student account upon verified request."""
    user = authenticate_student(enrollment, password)
    if not user:
        return False, "Incorrect password. Account deletion denied."

    conn = get_connection()
    if not conn: return False, "Database error."
    cursor = conn.cursor()
    try:
        cursor.execute("DELETE FROM students WHERE enrollment_number = %s", (enrollment.upper(),))
        conn.commit()
        return True, "Account successfully deleted."
    except Exception as e:
        print(f"[MySQL Delete Account Error] {e}")
        return False, "Failed to delete account."
    finally:
        conn.close()


def initiate_password_reset(enrollment: str, mobile: str) -> tuple[bool, str, str | None]:
    """
    Initiates password recovery.
    1. Looks up student by enrollment_number.
    2. Validates that the provided mobile matches the registered mobile number.
    3. To prevent account enumeration, if no match, returns a generic safe message without error.
    4. Enforces a 60-second resend cooldown.
    5. Invalidates any prior active OTPs for this account.
    6. Generates a secure random 6-digit OTP, stores its SHA-256 hash with 5-minute expiry.
    7. Dispatches the OTP via real SMS provider.
    Returns (success, message, dev_otp_if_testing).
    """
    enroll = str(enrollment).strip().upper()
    mob = str(mobile).strip().replace(" ", "").replace("-", "")

    if not enroll or not mob:
        return False, "Enrollment number and registered mobile number are required.", None

    conn = get_connection()
    if not conn:
        return False, "Database connection error.", None

    cursor = conn.cursor(pymysql.cursors.DictCursor)
    try:
        cursor.execute("SELECT enrollment_number, student_name, mobile_number FROM students WHERE enrollment_number = %s", (enroll,))
        student = cursor.fetchone()

        # If student doesn't exist or mobile does not match, return safe generic message
        if not student or str(student.get("mobile_number", "")).strip() != mob:
            return True, "If the account details are valid, an OTP will be sent to the registered mobile number.", None

        registered_mobile = student["mobile_number"]

        # Check 60-second cooldown
        one_min_ago = datetime.now() - timedelta(seconds=60)
        cursor.execute("""
            SELECT created_at FROM password_resets
            WHERE enrollment_number = %s AND is_used = FALSE AND created_at > %s
            ORDER BY id DESC LIMIT 1
        """, (enroll, one_min_ago))
        recent = cursor.fetchone()
        if recent:
            return False, "Please wait at least 60 seconds before requesting a new OTP.", None

        # Invalidate previous unused OTPs
        cursor.execute("UPDATE password_resets SET is_used = TRUE WHERE enrollment_number = %s AND is_used = FALSE", (enroll,))

        # Generate cryptographically secure random 6-digit OTP
        otp = f"{secrets.randbelow(900000) + 100000}"
        otp_hash = hashlib.sha256(otp.encode("utf-8")).hexdigest()
        expires_at = datetime.now() + timedelta(minutes=5)

        cursor.execute("""
            INSERT INTO password_resets (enrollment_number, mobile_number, otp_hash, otp_expires_at)
            VALUES (%s, %s, %s, %s)
        """, (enroll, registered_mobile, otp_hash, expires_at))
        conn.commit()

        # Dispatch via SMS service
        sms_ok, sms_msg = send_otp_sms(registered_mobile, otp)

        # Return generic safe message (plus OTP only if dev simulator)
        dev_otp = otp if ("logged to development console" in sms_msg or os.getenv("FLASK_ENV") != "production") else None
        return True, "If the account details are valid, an OTP will be sent to the registered mobile number.", dev_otp

    except Exception as e:
        print(f"[Password Reset Initiate Error] {e}")
        return False, "Failed to initiate password recovery. Please retry.", None
    finally:
        conn.close()


def verify_reset_otp(enrollment: str, otp: str) -> tuple[bool, str, str | None]:
    """
    Verifies the submitted 6-digit OTP.
    1. Rejects expired, already used, or >5 attempts.
    2. Increments attempt count on mismatch.
    3. On match, creates a single-use authorization token with 10-minute expiry.
    Returns (success, message, reset_token).
    """
    enroll = str(enrollment).strip().upper()
    otp_code = str(otp).strip()

    if not enroll or not otp_code or len(otp_code) != 6 or not otp_code.isdigit():
        return False, "Please enter a valid 6-digit verification OTP.", None

    conn = get_connection()
    if not conn:
        return False, "Database connection error.", None

    cursor = conn.cursor(pymysql.cursors.DictCursor)
    try:
        cursor.execute("""
            SELECT id, otp_hash, otp_expires_at, otp_attempts, is_verified, is_used
            FROM password_resets
            WHERE enrollment_number = %s AND is_used = FALSE AND is_verified = FALSE
            ORDER BY id DESC LIMIT 1
        """, (enroll,))
        record = cursor.fetchone()

        if not record:
            return False, "No active OTP found. Please request a new verification code.", None

        rec_id = record["id"]

        # Check expiry
        if datetime.now() > record["otp_expires_at"]:
            cursor.execute("UPDATE password_resets SET is_used = TRUE WHERE id = %s", (rec_id,))
            conn.commit()
            return False, "Verification code has expired. Please request a new code.", None

        # Check maximum attempts
        if record["otp_attempts"] >= 5:
            cursor.execute("UPDATE password_resets SET is_used = TRUE WHERE id = %s", (rec_id,))
            conn.commit()
            return False, "Maximum verification attempts exceeded. Please request a new code.", None

        # Check hash
        entered_hash = hashlib.sha256(otp_code.encode("utf-8")).hexdigest()
        if entered_hash != record["otp_hash"]:
            new_attempts = record["otp_attempts"] + 1
            cursor.execute("UPDATE password_resets SET otp_attempts = %s WHERE id = %s", (new_attempts, rec_id))
            conn.commit()
            remaining = max(0, 5 - new_attempts)
            return False, f"Invalid verification code. {remaining} attempt(s) remaining.", None

        # Match! Issue single-use reset token
        reset_token = secrets.token_urlsafe(32)
        token_expires_at = datetime.now() + timedelta(minutes=10)

        cursor.execute("""
            UPDATE password_resets
            SET is_verified = TRUE, reset_token = %s, token_expires_at = %s
            WHERE id = %s
        """, (reset_token, token_expires_at, rec_id))
        conn.commit()

        return True, "Verification successful.", reset_token

    except Exception as e:
        print(f"[Password Reset Verify Error] {e}")
        return False, "Failed to verify OTP.", None
    finally:
        conn.close()


def complete_password_reset(enrollment: str, reset_token: str, new_password: str) -> tuple[bool, str]:
    """
    Validates reset authorization token and updates student's password hash in MySQL.
    Consumes the reset token so it cannot be reused.
    """
    enroll = str(enrollment).strip().upper()
    token = str(reset_token).strip()
    pwd = str(new_password).strip()

    if not enroll or not token or not pwd:
        return False, "Missing required password reset fields."

    if len(pwd) < 4:
        return False, "New password must be at least 4 characters long."

    conn = get_connection()
    if not conn:
        return False, "Database connection error."

    cursor = conn.cursor(pymysql.cursors.DictCursor)
    try:
        cursor.execute("""
            SELECT id, token_expires_at, is_used, is_verified
            FROM password_resets
            WHERE enrollment_number = %s AND reset_token = %s AND is_verified = TRUE AND is_used = FALSE
        """, (enroll, token))
        record = cursor.fetchone()

        if not record:
            return False, "Invalid or already consumed password reset token. Please restart recovery."

        rec_id = record["id"]

        if datetime.now() > record["token_expires_at"]:
            cursor.execute("UPDATE password_resets SET is_used = TRUE WHERE id = %s", (rec_id,))
            conn.commit()
            return False, "Password reset session has expired. Please request a new OTP."

        # Hash new password
        pwd_hash = generate_password_hash(pwd)

        # Update student password and consume reset token
        cursor.execute("UPDATE students SET password_hash = %s WHERE enrollment_number = %s", (pwd_hash, enroll))
        cursor.execute("UPDATE password_resets SET is_used = TRUE WHERE id = %s", (rec_id,))
        conn.commit()

        return True, "Password has been successfully updated. Please sign in with your new password."

    except Exception as e:
        print(f"[Password Reset Complete Error] {e}")
        return False, "Failed to update password."
    finally:
        conn.close()


def get_emergency_by_id(emergency_id: int) -> dict | None:
    """Return a single emergency record as a dict, or None if not found."""
    conn = get_connection()
    if not conn: return None
    cursor = conn.cursor(pymysql.cursors.DictCursor)
    cursor.execute("SELECT * FROM emergencies WHERE id = %s", (emergency_id,))
    row = cursor.fetchone()
    conn.close()
    return dict(row) if row else None


def get_emergencies() -> pd.DataFrame:
    """Return all emergency records ordered newest-first."""
    conn = get_connection()
    if not conn: return pd.DataFrame()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM emergencies ORDER BY id DESC")
    rows = cursor.fetchall()
    conn.close()
    if not rows:
        return pd.DataFrame()
    return pd.DataFrame(rows)


def update_status(emergency_id: int, status: str):
    """Update the status of an emergency and stamp the relevant timestamp."""
    conn = get_connection()
    if not conn: return
    cursor = conn.cursor()

    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    timestamp_map = {
        "Dispatched": "dispatch_time",
        "On the Way": "on_way_time",
        "Arrived":    "arrived_time",
        "Resolved":   "resolved_time",
    }

    if status in timestamp_map:
        col = timestamp_map[status]
        cursor.execute(
            f"UPDATE emergencies SET status = %s, {col} = %s WHERE id = %s",
            (status, now, emergency_id)
        )
    else:
        cursor.execute(
            "UPDATE emergencies SET status = %s WHERE id = %s",
            (status, emergency_id)
        )

    conn.commit()
    conn.close()


# =========================================================
# INITIALISE ON IMPORT
# =========================================================

create_database()
add_missing_columns()
create_students_table()
create_password_resets_table()
