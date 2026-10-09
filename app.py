# =========================================================
# RAKSHAK AI  -  Flask Web Application Entry Point
# Run with:  python app.py
# =========================================================

import os, json, math, time, threading
from datetime import datetime
from flask import Flask, render_template, request, jsonify, Response, stream_with_context, session, redirect, url_for
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv(override=True)

from config.locations import campus_locations, responders
from core.analyzer import smart_analyze
from core.groq_ai import is_groq_available
from core.responder import find_nearest_responder, estimate_response_minutes, calculate_distance
from database.db import (
    create_database, add_missing_columns, add_emergency, get_emergencies,
    update_status, get_emergency_by_id, save_student_profile,
    register_student, authenticate_student, get_student_profile,
    get_student_emergencies, delete_student_account,
    initiate_password_reset, verify_reset_otp, complete_password_reset,
    create_password_resets_table
)

app = Flask(__name__, template_folder="templates", static_folder="static")
app.secret_key = os.getenv("SECRET_KEY", "mewar-guardian-production-secret-2026-secure")
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
)

CORS(
    app,
    supports_credentials=True,
    origins=["https://mewar-guardian.onrender.com", "http://localhost:3000", "http://localhost:5000", "http://127.0.0.1:5000", "*"]
)

def is_admin_authorized():
    if session.get('sec_logged_in'):
        return True
    auth_header = request.headers.get("Authorization", "")
    admin_header = request.headers.get("X-Admin-Password", "")
    expected = os.getenv("SECURITY_PASS", "admin123")
    if admin_header and admin_header == expected:
        return True
    if auth_header.startswith("Bearer ") and auth_header[7:].strip() == expected:
        return True
    return False

_sse_clients = []
_sse_lock = threading.Lock()

def push_sse_event(data):
    payload = "data: " + json.dumps(data) + "\n\n"
    with _sse_lock:
        for q in list(_sse_clients):
            q.append(payload)

# ----------------------------------------------------------
# PAGE ROUTES
# ----------------------------------------------------------
@app.route("/")
def index():
    return render_template("index.html")

@app.route("/security")
def security():
    if not session.get('sec_logged_in'):
        return redirect(url_for('security_login'))
    return render_template("security.html")

@app.route("/security-login", methods=["GET", "POST"])
def security_login():
    if request.method == "POST":
        pwd = request.form.get("password", "")
        if pwd == os.getenv("SECURITY_PASS", "admin123"):
            session['sec_logged_in'] = True
            return redirect(url_for('security'))
        return render_template("security_login.html", error="Invalid password!")
    return render_template("security_login.html", error=None)

@app.route("/security-logout")
def security_logout():
    session.pop('sec_logged_in', None)
    return redirect(url_for('index'))

# ----------------------------------------------------------
# API - HEALTH & LOCATIONS
# ----------------------------------------------------------

@app.route("/api/health", methods=["GET"])
def health_check():
    return jsonify({"status": "ok", "message": "Rakshak AI Backend is running", "timestamp": datetime.now().isoformat()}), 200


# ----------------------------------------------------------
@app.route("/api/locations")
def api_locations():
    locs = []
    for name, data in campus_locations.items():
        locs.append({"name": name, "lat": data["lat"], "lon": data["lon"],
                     "category": data["category"], "verified": data.get("verified", False)})
    return jsonify({"locations": locs})

@app.route("/api/responders")
def api_responders():
    teams = []
    for name, data in responders.items():
        teams.append({"name": name, "lat": data["lat"], "lon": data["lon"]})
    return jsonify({"responders": teams})

# ----------------------------------------------------------
# API - AI CHAT
# ----------------------------------------------------------
_HINDI_EMERGENCY_WORDS = [
    "aag", "aag lag", "behosh", "unconscious", "khoon", "bleeding",
    "attack", "maar", "peecha", "lad", "fight", "accident", "gir gaya",
    "ghabrahat", "dard", "chot", "injured", "smoke", "dhuaan",
    "help", "bachao", "madad", "emergency", "dhamki", "threat",
    "threaten", "harass", "harassment", "disturb", "pareshaan"
]

_CRITICAL_TRIGGERS = [
    "behosh", "unconscious", "not breathing", "aag lag", "fire in",
    "bleeding", "khoon aa", "attack", "maar", "bomb", "goli",
    "hostel me aag", "collapsed", "faint", "ek aadmi", "ek ladka",
    "koi behosh", "bhai mujhe", "mere saamne", "help me",
    "dhamki de", "threaten", "harassing me", "harassment"
]

CHAT_SYSTEM_PROMPT = """You are Mewar Guardian AI - an intelligent campus emergency and safety assistant for Mewar University.

Developer & Creator Information:
- Creator & Developer: Nagin Daksh
- Project: Mewar Guardian (AI-Powered Campus Safety & Emergency Response)
- Purpose: AI-powered campus safety, rapid SOS alerts, emergency responder dispatch, and student protection.
- Role: Nagin Daksh is the project developer and creator who architected and built the Mewar Guardian application, system infrastructure, and safety assistant integration.
- Model Architecture Clarification: Clearly distinguish that Nagin Daksh developed the Mewar Guardian platform and campus safety application; the underlying base intelligence is powered by modern open language models via Groq.

When asked about your developer, creator, or who made/built you, or who Nagin Daksh is:
- Examples of questions:
  * "Who is your developer?" / "Who created you?" / "Who made you?" / "Who developed Mewar Guardian AI?"
  * "Tumhara developer kaun hai?" / "Tumhe kisne banaya?" / "Tera creator kaun hai?"
  * "Nagin Daksh kaun hai?" / "Who is Nagin Daksh?"
- Respond naturally, warmly, and confidently in the EXACT language used by the user:
  * English: "I was developed by Nagin Daksh as part of the Mewar Guardian project, an AI-powered campus safety and emergency response system."
  * Hindi: "Mujhe Nagin Daksh ne Mewar Guardian project ke under develop kiya hai. Main campus safety aur emergency response mein help karne ke liye bana hoon."
  * Hinglish: "Bhai, mere developer Nagin Daksh hain! Unhone mujhe Mewar Guardian project ke liye banaya hai, taaki campus mein emergency ke time students ko help mil sake."
  * If asked about Nagin Daksh: "Nagin Daksh is the developer and creator of the Mewar Guardian project, an AI-powered campus safety and emergency response system."
- For developer identity questions: is_emergency=false, emergency_type=null, priority=null, risk_score=null, should_sos=false, ask_sos=false, safety_tips=[].

You understand English, Hindi, and Hinglish perfectly.

ALWAYS respond with ONLY valid JSON in this exact format:
{
  "message": "<your reply in same language as user, warm and caring>",
  "is_emergency": <true|false>,
  "emergency_type": "<Medical Emergency|Fire|Security Issue|Accident|Threat|Harassment|Other|null>",
  "priority": "<CRITICAL|HIGH|MEDIUM|LOW|null>",
  "risk_score": <0-100 or null>,
  "confidence": <0.0-1.0>,
  "detected_location": "<campus location name if mentioned, else null>",
  "should_sos": <true if life-threatening and needs immediate SOS>,
  "ask_sos": <true if uncertain emergency, ask user>,
  "safety_tips": ["<tip>"] or []
}

Campus locations include: Engineering Block, Library/Computer Science, Hospital, Sanga Hostel, Kumbha Hostel, International Hostel, Pratap Hostel, Meera Hostel, Panna Hostel, Main Building, Auditorium, Canteen, Mess/Dining, Guard Room, Main Gate, Parking, Football Ground.

Rules:
- For fire, unconscious person, bleeding, violent attack: is_emergency=true, should_sos=true
- For uncertain situations: ask_sos=true, ask user "Kya aapko abhi turant help chahiye?"
- For normal greetings/questions: is_emergency=false, all emergency fields null
- Always respond in the same language as the user
- Be warm, calm, and reassuring
- NEVER return anything except valid JSON"""

def _get_developer_response(text: str) -> dict | None:
    """
    Recognizes questions about developer, creator, and Nagin Daksh across
    English, Hindi, and Hinglish with natural, accurate responses.
    """
    t = text.lower().strip()
    
    is_nagin_query = any(k in t for k in ["nagin daksh", "nagin", "daksh"])
    is_dev_query = any(k in t for k in [
        "developer", "creator", "created you", "made you", "built you",
        "who made", "who created", "who developed", "who programmed",
        "kisne banaya", "banaya kisne", "developer kaun", "creator kaun",
        "kisne develop", "tumhara developer", "tera developer", "aapka developer",
        "tumhara creator", "tera creator", "aapka creator", "tumhe kisne",
        "tujhe kisne", "aapko kisne", "kiska project", "kisne banaya hai"
    ])

    if not (is_nagin_query or is_dev_query):
        return None

    hindi_keywords = [
        "kaun", "hai", "kisne", "banaya", "tumhe", "tera", "tumhara",
        "aapka", "kiska", "bhai", "yaar", "ke baare", "batao", "mujhe",
        "namaste", "unhone", "karein", "kya", "hain"
    ]
    is_hindi_hinglish = any(hk in t for hk in hindi_keywords)
    is_hinglish_casual = any(ck in t for ck in ["bhai", "tera", "yaar", "tujhe", "bro", "arre"])

    if is_nagin_query and not any(k in t for k in ["other than", "not nagin"]):
        if is_hinglish_casual:
            msg = "Bhai, Nagin Daksh Mewar Guardian project ke developer aur creator hain! Unhone campus safety aur emergency response ke liye is pure system aur AI platform ko banaya hai."
        elif is_hindi_hinglish:
            msg = "Nagin Daksh Mewar Guardian project ke developer aur creator hain. Unhone campus safety aur emergency response ke liye is complete system aur application ko design aur develop kiya hai."
        else:
            msg = "Nagin Daksh is the developer and creator of the Mewar Guardian project, an AI-powered campus safety and emergency response system."
    elif is_hinglish_casual:
        msg = "Bhai, mere developer Nagin Daksh hain! Unhone mujhe Mewar Guardian project ke liye banaya hai, taaki campus mein emergency ke time students ko help mil sake."
    elif is_hindi_hinglish:
        msg = "Mujhe Nagin Daksh ne Mewar Guardian project ke under develop kiya hai. Main campus safety aur emergency response mein help karne ke liye bana hoon."
    else:
        msg = "I was developed by Nagin Daksh as part of the Mewar Guardian project, an AI-powered campus safety and emergency response system."

    return {
        "message": msg,
        "is_emergency": False,
        "emergency_type": None,
        "priority": None,
        "risk_score": None,
        "confidence": 1.0,
        "detected_location": None,
        "should_sos": False,
        "ask_sos": False,
        "safety_tips": []
    }

def _detect_local_emergency(text):
    t = text.lower()
    has_signal = any(kw in t for kw in _HINDI_EMERGENCY_WORDS)
    is_critical = any(kw in t for kw in _CRITICAL_TRIGGERS)
    return has_signal, is_critical

def _match_location(text):
    t = text.lower()
    best, best_score = None, 0
    for loc_name in campus_locations:
        words = loc_name.lower().split()
        score = sum(1 for w in words if len(w) > 3 and w in t)
        if "hostel" in t and "hostel" in loc_name.lower(): score += 0.5
        if score > best_score:
            best_score, best = score, loc_name
    return best if best_score > 0 else None

@app.route("/api/chat", methods=["POST"])
def api_chat():
    body = request.get_json(force=True)
    user_message = body.get("message", "").strip()
    history = body.get("history", [])

    if not user_message:
        return jsonify({"error": "Empty message"}), 400

    has_signal, is_critical = _detect_local_emergency(user_message)
    dev_direct_match = _get_developer_response(user_message)

    if is_groq_available():
        try:
            from groq import Groq
            client = Groq(api_key=os.getenv("GROQ_API_KEY", ""))
            msgs = [{"role": "system", "content": CHAT_SYSTEM_PROMPT}]
            for h in history[-8:]:
                msgs.append({"role": h["role"], "content": h["content"]})
            msgs.append({"role": "user", "content": user_message})

            resp = client.chat.completions.create(
                model="openai/gpt-oss-120b", messages=msgs,
                temperature=0.4, max_tokens=800, timeout=6.0
            )
            raw = resp.choices[0].message.content.strip()
            if raw.startswith("```"):
                parts = raw.split("```")
                raw = parts[1] if len(parts) > 1 else raw
                if raw.startswith("json"): raw = raw[4:]
            raw = raw.strip()
            result = json.loads(raw)

            # If user asked about developer/creator, guarantee Nagin Daksh is recognized
            if dev_direct_match:
                if "nagin" not in result.get("message", "").lower():
                    result["message"] = dev_direct_match["message"]
                result["is_emergency"] = False
                result["should_sos"] = False

            if is_critical and not result.get("is_emergency"):
                result["is_emergency"] = True
                result["should_sos"] = True
            if not result.get("detected_location"):
                matched = _match_location(user_message)
                if matched: result["detected_location"] = matched
            return jsonify(result)
        except Exception as e:
            print(f"[Chat error] {e}")

    # Fallback if Groq unavailable or had exception
    if dev_direct_match:
        return jsonify(dev_direct_match)

    if has_signal or is_critical:
        pred, conf, prio, risk, rec, _ = smart_analyze(user_message, "")
        loc = _match_location(user_message)
        return jsonify({
            "message": f"Yeh {pred} emergency lag rahi hai (Priority: {prio}). Kya main campus security ko alert karun?",
            "is_emergency": True, "emergency_type": pred, "priority": prio,
            "risk_score": risk, "confidence": round(conf/100, 2),
            "detected_location": loc, "should_sos": prio in ["CRITICAL","HIGH"],
            "ask_sos": prio in ["MEDIUM","LOW"], "safety_tips": [rec]
        })
    return jsonify({
        "message": "Namaste! Main Mewar Guardian AI hoon. Campus safety ke baare mein kuch poochna hai? Ya koi emergency hai?",
        "is_emergency": False, "emergency_type": None, "priority": None,
        "risk_score": None, "confidence": 0.95, "detected_location": None,
        "should_sos": False, "ask_sos": False, "safety_tips": []
    })

# ----------------------------------------------------------
# API - EMERGENCY CRUD
# ----------------------------------------------------------
_recent_submissions = {}
_idempotency_lock = threading.Lock()

@app.route("/api/emergency", methods=["POST"])
def api_create_emergency():
    body = request.get_json(force=True)
    student_name   = body.get("student_name", "Anonymous")
    mobile_number  = body.get("mobile_number", "")
    enrollment_number = body.get("enrollment_number", "")
    description    = body.get("description", "")
    location       = body.get("location", "Main Campus Reference")
    emergency_type = body.get("emergency_type", "")
    priority       = body.get("priority", "")
    risk_score     = body.get("risk_score", 50)
    ai_confidence  = body.get("ai_confidence", 75.0)
    student_lat    = body.get("student_lat")
    student_lon    = body.get("student_lon")
    location_accuracy = body.get("location_accuracy")
    client_request_id = body.get("client_request_id")

    # Idempotency check: prevent duplicate submissions within 30 seconds
    now = time.time()
    idemp_key = client_request_id or f"{student_name}:{location}:{description}"
    with _idempotency_lock:
        # Clean stale keys
        stale = [k for k, v in _recent_submissions.items() if now - v.get("time", 0) > 60]
        for k in stale: _recent_submissions.pop(k, None)

        if idemp_key in _recent_submissions:
            cached_resp = _recent_submissions[idemp_key].get("response")
            if cached_resp:
                return jsonify(cached_resp), 200

    recommendation = ""
    try:
        if not emergency_type or not priority:
            pred, conf, prio, risk, rec, _ = smart_analyze(description, location)
            emergency_type = emergency_type or pred
            priority = priority or prio
            risk_score = risk_score or risk
            ai_confidence = ai_confidence or conf
            recommendation = rec
        else:
            _, _, _, _, recommendation, _ = smart_analyze(description, location)
    except Exception as e:
        print(f"[Analysis fallback] {e}")
        emergency_type = emergency_type or "Security Issue"
        priority = priority or "HIGH"
        recommendation = "Campus response team notified. Remain in a safe location."

    if location in campus_locations:
        inc_lat = campus_locations[location]["lat"]
        inc_lon = campus_locations[location]["lon"]
    elif student_lat and student_lon:
        inc_lat, inc_lon = float(student_lat), float(student_lon)
    else:
        inc_lat = campus_locations["Main Campus Reference"]["lat"]
        inc_lon = campus_locations["Main Campus Reference"]["lon"]

    etype_lower = str(emergency_type).lower()
    if "medical" in etype_lower:
        responder_name = "Medical Team"
    elif "fire" in etype_lower:
        responder_name = "Fire Response Team"
    else:
        responder_name = "Security Team"

    resp_data = responders.get(responder_name, responders["Security Team"])
    distance = calculate_distance(inc_lat, inc_lon, resp_data["lat"], resp_data["lon"])
    estimated_minutes = estimate_response_minutes(distance, priority)

    try:
        emergency_id = add_emergency(
            student_name=student_name, emergency_type=emergency_type,
            location=location, description=description, priority=priority,
            responder=responder_name, distance=distance, ai_confidence=float(ai_confidence),
            risk_score=int(risk_score), recommendation=recommendation,
            estimated_minutes=estimated_minutes,
            student_lat=student_lat, student_lon=student_lon,
            mobile_number=mobile_number, enrollment_number=enrollment_number,
            location_accuracy=location_accuracy,
            responder_lat=resp_data["lat"], responder_lon=resp_data["lon"]
        )
    except Exception as e:
        print(f"[Database error] {e}")
        return jsonify({"success": False, "error": "Database error persisting emergency."}), 500

    if not emergency_id or emergency_id <= 0:
        return jsonify({"success": False, "error": "Could not generate emergency record ID."}), 500

    push_sse_event({
        "type": "new_emergency", "id": emergency_id,
        "student_name": student_name,
        "mobile_number": mobile_number,
        "enrollment_number": enrollment_number,
        "emergency_type": emergency_type,
        "location": location, "priority": priority,
        "risk_score": int(risk_score), "ai_confidence": float(ai_confidence),
        "description": description, "responder": responder_name,
        "estimated_minutes": estimated_minutes,
        "reported_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    })

    resp_payload = {
        "success": True, "emergency_id": emergency_id,
        "emergency_type": emergency_type, "priority": priority,
        "risk_score": int(risk_score), "ai_confidence": float(ai_confidence),
        "responder": responder_name, "distance_m": round(distance * 1000, 1),
        "estimated_minutes": estimated_minutes, "location": location,
        "incident_lat": inc_lat, "incident_lon": inc_lon,
        "responder_lat": resp_data["lat"], "responder_lon": resp_data["lon"],
        "recommendation": recommendation
    }

    with _idempotency_lock:
        _recent_submissions[idemp_key] = {"time": now, "response": resp_payload}

    return jsonify(resp_payload), 200


@app.route("/api/emergencies", methods=["GET"])
def api_get_emergencies():
    if not is_admin_authorized():
        return jsonify({"error": "Unauthorized"}), 401
        
    df = get_emergencies()
    if df.empty:
        return jsonify({"emergencies": []})
        
    df = df.fillna("")
    emergencies = []
    for _, row in df.iterrows():
        t = row.get("time")
        if hasattr(t, "strftime"):
            time_str = t.strftime("%Y-%m-%d %H:%M:%S")
        else:
            time_str = str(t)
            
        row_id = row.get("id")
        try:
            eid_val = int(row_id)
        except (ValueError, TypeError):
            continue

        def _safe_float(v):
            try:
                val = float(v)
                return val if not math.isnan(val) else None
            except (ValueError, TypeError):
                return None

        def _safe_int(v):
            try:
                return int(v)
            except (ValueError, TypeError):
                return None

        emergencies.append({
            "id": eid_val,
            "student_name": str(row.get("student_name", "")),
            "mobile_number": str(row.get("mobile_number", "")),
            "enrollment_number": str(row.get("enrollment_number", "")),
            "emergency_type": str(row.get("emergency_type", "")),
            "location": str(row.get("location", "")),
            "description": str(row.get("description", "")),
            "priority": str(row.get("priority", "")),
            "status": str(row.get("status", "")),
            "time": time_str,
            "responder": str(row.get("responder", "")),
            "distance": _safe_float(row.get("distance")),
            "estimated_minutes": _safe_int(row.get("estimated_minutes")),
            "ai_confidence": _safe_float(row.get("ai_confidence")),
            "risk_score": _safe_int(row.get("risk_score")),
            "recommendation": str(row.get("recommendation", "")),
            "incident_lat": _safe_float(row.get("student_lat")),
            "incident_lon": _safe_float(row.get("student_lon")),
            "location_accuracy": _safe_float(row.get("location_accuracy")),
        })
    return jsonify({"emergencies": emergencies})

@app.route("/api/emergency/<int:eid>")
def api_get_emergency(eid):
    row = get_emergency_by_id(eid)
    if not row:
        return jsonify({"error": "Not found"}), 404
        
    # Mask PII if not logged in as security
    if not is_admin_authorized():
        row.pop("student_name", None)
        row.pop("mobile_number", None)
        row.pop("enrollment_number", None)
        
        # Mask sensitive types
        t = str(row.get("emergency_type", "")).lower()
        if "threat" in t or "harassment" in t:
            row["emergency_type"] = "Confidential Report"
            row["description"] = "Details hidden for privacy."
            
    return jsonify(row)

@app.route("/api/emergency/<int:eid>/status", methods=["POST"])
def api_update_status(eid):
    if not is_admin_authorized():
        return jsonify({"error": "Unauthorized"}), 401
    body = request.get_json(force=True)
    status = body.get("status", "")
    valid = ["Dispatched", "On the Way", "Arrived", "Resolved"]
    if status not in valid:
        return jsonify({"error": "Invalid status"}), 400
    update_status(eid, status)
    push_sse_event({
        "type": "status_update", "id": eid, "status": status,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    })
    return jsonify({"success": True, "id": eid, "status": status})

# ----------------------------------------------------------
# API - AUTHENTICATION & STUDENT MANAGEMENT
# ----------------------------------------------------------
_auth_rate_limit = {}
_auth_lock = threading.Lock()

def _check_rate_limit(key: str, max_requests: int = 15, window_sec: int = 60) -> bool:
    now = time.time()
    with _auth_lock:
        timestamps = _auth_rate_limit.get(key, [])
        timestamps = [t for t in timestamps if now - t < window_sec]
        if len(timestamps) >= max_requests:
            return False
        timestamps.append(now)
        _auth_rate_limit[key] = timestamps
        return True

@app.route("/api/register", methods=["POST"])
def api_register():
    ip = request.remote_addr or "127.0.0.1"
    if not _check_rate_limit(f"reg:{ip}", max_requests=15, window_sec=60):
        return jsonify({"success": False, "error": "Too many registration attempts. Please wait 1 minute."}), 429

    body = request.get_json(force=True)
    name = body.get("name", "").strip()
    mobile = body.get("mobile", "").strip()
    enroll = body.get("enrollment", "").strip()
    pwd = body.get("password", "").strip()

    ok, msg = register_student(enrollment=enroll, name=name, mobile=mobile, password=pwd)
    if not ok:
        return jsonify({"success": False, "error": msg}), 400

    session['student_enrollment'] = enroll.upper()
    return jsonify({
        "success": True,
        "message": msg,
        "student": {
            "student_name": name,
            "mobile_number": mobile,
            "enrollment_number": enroll.upper(),
            "role": "Student"
        }
    }), 201

@app.route("/api/login", methods=["POST"])
def api_login():
    ip = request.remote_addr or "127.0.0.1"
    if not _check_rate_limit(f"login:{ip}", max_requests=25, window_sec=60):
        return jsonify({"success": False, "error": "Too many login attempts. Please wait 1 minute."}), 429

    body = request.get_json(force=True)
    ident = body.get("identifier", "").strip()
    pwd = body.get("password", "").strip()

    if not ident or not pwd:
        return jsonify({"success": False, "error": "Enrollment number / mobile and password are required."}), 400

    student = authenticate_student(ident, pwd)
    if not student:
        return jsonify({"success": False, "error": "Invalid credentials. Please verify your enrollment number or mobile and password."}), 401

    session['student_enrollment'] = student["enrollment_number"]
    return jsonify({
        "success": True,
        "student": student
    }), 200

@app.route("/api/profile", methods=["GET", "POST"])
def api_profile():
    if request.method == "GET":
        enroll = request.args.get("enrollment", "").strip() or session.get("student_enrollment", "")
        if not enroll:
            return jsonify({"success": False, "error": "Enrollment identifier required."}), 400
        prof = get_student_profile(enroll)
        if not prof:
            return jsonify({"success": False, "error": "Student profile not found."}), 404
        return jsonify({"success": True, "profile": prof}), 200

    # POST - update profile
    body = request.get_json(force=True)
    name = body.get("name", "").strip()
    mobile = body.get("mobile", "").strip()
    enroll = body.get("enrollment", "").strip()

    if not name or not mobile or not enroll:
        return jsonify({"success": False, "error": "Missing required profile fields."}), 400

    success = save_student_profile(enroll, name, mobile)
    return jsonify({"success": success})

@app.route("/api/my-emergencies", methods=["GET"])
def api_my_emergencies():
    enroll = request.args.get("enrollment", "").strip() or session.get("student_enrollment", "")
    mobile = request.args.get("mobile", "").strip()
    ident = enroll or mobile
    if not ident:
        return jsonify({"success": False, "error": "Enrollment or mobile identifier required."}), 400

    emergencies = get_student_emergencies(ident)
    return jsonify({"success": True, "emergencies": emergencies}), 200

@app.route("/api/account/delete", methods=["POST"])
def api_delete_account():
    body = request.get_json(force=True)
    enroll = body.get("enrollment", "").strip()
    pwd = body.get("password", "").strip()

    if not enroll or not pwd:
        return jsonify({"success": False, "error": "Enrollment and password confirmation required for account deletion."}), 400

    ok, msg = delete_student_account(enroll, pwd)
    if not ok:
        return jsonify({"success": False, "error": msg}), 400

    session.pop("student_enrollment", None)
    return jsonify({"success": True, "message": msg}), 200

@app.route("/api/logout", methods=["POST"])
def api_logout():
    session.pop("student_enrollment", None)
    return jsonify({"success": True, "message": "Logged out successfully."}), 200

# ----------------------------------------------------------
# API - PASSWORD RECOVERY (FORGOT / RESET PASSWORD)
# ----------------------------------------------------------
@app.route("/api/auth/forgot-password", methods=["POST"])
def api_forgot_password():
    ip = request.remote_addr or "127.0.0.1"
    if not _check_rate_limit(f"forgot:{ip}", max_requests=10, window_sec=60):
        return jsonify({"success": False, "error": "Too many password recovery requests. Please wait 1 minute."}), 429

    body = request.get_json(force=True)
    enroll = (body.get("enrollment") or body.get("enrollment_number") or "").strip()
    mobile = (body.get("mobile") or body.get("mobile_number") or "").strip()

    if not enroll or not mobile:
        return jsonify({"success": False, "error": "Enrollment number and registered mobile number are required."}), 400

    ok, msg, dev_otp = initiate_password_reset(enroll, mobile)
    if not ok:
        return jsonify({"success": False, "error": msg}), 400

    resp_data = {"success": True, "message": msg}
    if dev_otp:
        resp_data["dev_otp"] = dev_otp
    return jsonify(resp_data), 200

@app.route("/api/auth/verify-reset-otp", methods=["POST"])
def api_verify_reset_otp():
    ip = request.remote_addr or "127.0.0.1"
    if not _check_rate_limit(f"verify:{ip}", max_requests=15, window_sec=60):
        return jsonify({"success": False, "error": "Too many OTP verification attempts. Please wait 1 minute."}), 429

    body = request.get_json(force=True)
    enroll = (body.get("enrollment") or body.get("enrollment_number") or "").strip()
    otp = str(body.get("otp", "")).strip()

    if not enroll or not otp:
        return jsonify({"success": False, "error": "Enrollment number and OTP are required."}), 400

    ok, msg, reset_token = verify_reset_otp(enroll, otp)
    if not ok:
        return jsonify({"success": False, "error": msg}), 400

    return jsonify({
        "success": True,
        "message": msg,
        "reset_token": reset_token
    }), 200

@app.route("/api/auth/reset-password", methods=["POST"])
def api_reset_password():
    ip = request.remote_addr or "127.0.0.1"
    if not _check_rate_limit(f"reset:{ip}", max_requests=10, window_sec=60):
        return jsonify({"success": False, "error": "Too many password reset attempts. Please wait 1 minute."}), 429

    body = request.get_json(force=True)
    enroll = (body.get("enrollment") or body.get("enrollment_number") or "").strip()
    token = (body.get("reset_token") or body.get("token") or "").strip()
    new_pwd = (body.get("new_password") or body.get("password") or "").strip()
    confirm_pwd = body.get("confirm_password")

    if not enroll or not token or not new_pwd:
        return jsonify({"success": False, "error": "Enrollment number, authorization token, and new password are required."}), 400

    if confirm_pwd is not None and confirm_pwd.strip() != new_pwd:
        return jsonify({"success": False, "error": "New password and confirmation password do not match."}), 400

    ok, msg = complete_password_reset(enroll, token, new_pwd)
    if not ok:
        return jsonify({"success": False, "error": msg}), 400

    return jsonify({"success": True, "message": msg}), 200

# ----------------------------------------------------------
# API - ROUTING (OSRM proxy)
# ----------------------------------------------------------
@app.route("/api/route")
def api_route():
    import requests as req
    from_lat = request.args.get("from_lat")
    from_lon = request.args.get("from_lon")
    to_lat   = request.args.get("to_lat")
    to_lon   = request.args.get("to_lon")
    if not all([from_lat, from_lon, to_lat, to_lon]):
        return jsonify({"error": "Missing coords"}), 400
    try:
        url = (f"https://router.project-osrm.org/route/v1/driving/"
               f"{from_lon},{from_lat};{to_lon},{to_lat}?overview=full&geometries=geojson")
        r = req.get(url, timeout=8)
        return jsonify(r.json())
    except Exception as e:
        return jsonify({"error": str(e), "code": "RoutingFailed"})

# ----------------------------------------------------------
# API - ETA
# ----------------------------------------------------------
@app.route("/api/eta", methods=["POST"])
def api_eta():
    body = request.get_json(force=True)
    s_lat = float(body.get("student_lat", 0))
    s_lon = float(body.get("student_lon", 0))
    r_lat = float(body.get("responder_lat", 0))
    r_lon = float(body.get("responder_lon", 0))
    priority = body.get("priority", "HIGH")
    distance = calculate_distance(s_lat, s_lon, r_lat, r_lon)
    minutes = estimate_response_minutes(distance, priority)
    return jsonify({
        "distance_m": round(distance * 1000, 1),
        "distance_km": round(distance, 3),
        "estimated_minutes": minutes,
        "eta_seconds": minutes * 60,
        "calculated_at": datetime.now().strftime("%H:%M:%S")
    })

# ----------------------------------------------------------
# API - ANALYTICS
# ----------------------------------------------------------
@app.route("/api/analytics")
def api_analytics():
    if not session.get('sec_logged_in'):
        return jsonify({"error": "Unauthorized"}), 401
    import pandas as pd
    df = get_emergencies()
    if df.empty:
        return jsonify({"total": 0, "by_type": {}, "by_priority": {},
                        "by_status": {}, "by_location": {},
                        "avg_dispatch_min": None, "avg_arrival_min": None,
                        "avg_resolution_min": None, "recent": [],
                        "pending": 0, "dispatched": 0, "on_way": 0,
                        "arrived": 0, "resolved": 0})
    df = df.fillna("")
    for col in ["time", "dispatch_time", "arrived_time", "resolved_time"]:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")

    def avg_min(c1, c2):
        if c1 in df.columns and c2 in df.columns:
            d = (df[c2] - df[c1]).dt.total_seconds() / 60
            v = d.dropna().mean()
            return round(float(v), 1) if not (v != v) else None
        return None

    recent = []
    for _, row in df.head(5).iterrows():
        t = row.get("time")
        recent.append({
            "id": int(row["id"]) if str(row.get("id", "")) != "" else None,
            "student_name": str(row.get("student_name", "")),
            "emergency_type": str(row.get("emergency_type", "")),
            "location": str(row.get("location", "")),
            "priority": str(row.get("priority", "")),
            "status": str(row.get("status", "")),
            "time": t.strftime("%Y-%m-%d %H:%M:%S") if pd.notna(t) else ""
        })

    return jsonify({
        "total": len(df),
        "pending":    len(df[df["status"] == "Pending"]),
        "dispatched": len(df[df["status"] == "Dispatched"]),
        "on_way":     len(df[df["status"] == "On the Way"]),
        "arrived":    len(df[df["status"] == "Arrived"]),
        "resolved":   len(df[df["status"] == "Resolved"]),
        "by_type":     df["emergency_type"].value_counts().to_dict(),
        "by_priority": df["priority"].value_counts().to_dict(),
        "by_status":   df["status"].value_counts().to_dict(),
        "by_location": df["location"].value_counts().head(10).to_dict(),
        "avg_dispatch_min":   avg_min("time", "dispatch_time"),
        "avg_arrival_min":    avg_min("time", "arrived_time"),
        "avg_resolution_min": avg_min("time", "resolved_time"),
        "recent": recent
    })

# ----------------------------------------------------------
# SSE - REAL-TIME STREAM
# ----------------------------------------------------------
@app.route("/api/stream")
def api_stream():
    client_queue = []
    with _sse_lock:
        _sse_clients.append(client_queue)

    def generate():
        yield "data: " + json.dumps({"type": "connected"}) + "\n\n"
        heartbeat_counter = 0
        try:
            while True:
                if client_queue:
                    msg = client_queue.pop(0)
                    yield msg
                else:
                    time.sleep(1)
                    heartbeat_counter += 1
                    if heartbeat_counter >= 15:
                        yield ": heartbeat\n\n"
                        heartbeat_counter = 0
        except GeneratorExit:
            pass
        finally:
            with _sse_lock:
                if client_queue in _sse_clients:
                    _sse_clients.remove(client_queue)

    return Response(
        stream_with_context(generate()),
        mimetype="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no", "Connection": "keep-alive"}
    )

# ----------------------------------------------------------
# API - STATUS
# ----------------------------------------------------------
@app.route("/api/status")
def api_status():
    return jsonify({
        "groq_available": is_groq_available(),
        "model": "openai/gpt-oss-120b" if is_groq_available() else "sklearn/LogisticRegression",
        "locations_count": len(campus_locations),
        "responders_count": len(responders),
        "system": "online"
    })

if __name__ == "__main__":
    create_database()
    add_missing_columns()
    create_password_resets_table()
    print("=" * 60)
    print("  Shield  RAKSHAK AI  -  Flask Web Server")
    print("=" * 60)
    print(f"  AI Engine : {'Groq LLM (openai/gpt-oss-120b)' if is_groq_available() else 'Local sklearn ML'}")
    print(f"  Locations : {len(campus_locations)} campus locations loaded")
    print(f"  Responders: {len(responders)} response teams")
    print("  URL       : http://127.0.0.1:5000")
    print("=" * 60)
    app.run(debug=False, use_reloader=False, host="0.0.0.0", port=5000, threaded=True)
