# =========================================================
# STUDENT PANEL  –  Emergency reporting UI
# =========================================================

import streamlit as st
import folium
from streamlit_folium import st_folium
from datetime import datetime, timedelta

from config.locations import campus_locations, responders
from core.analyzer import smart_analyze
from core.groq_ai import is_groq_available
from core.responder import find_nearest_responder, estimate_response_minutes
from database.db import add_emergency


def render():
    """Render the full Student Panel page."""

    # AI engine badge
    if is_groq_available():
        st.markdown(
            "<div style='display:inline-flex;align-items:center;gap:8px;padding:5px 14px;"
            "border-radius:999px;background:#f0fdf4;border:1px solid #86efac;"
            "color:#15803d;font-size:13px;font-weight:600;margin-bottom:10px;'>"
            "🤖 Powered by <b>Groq LLM</b> (openai/gpt-oss-120b)</div>",
            unsafe_allow_html=True
        )
    else:
        st.markdown(
            "<div style='display:inline-flex;align-items:center;gap:8px;padding:5px 14px;"
            "border-radius:999px;background:#fefce8;border:1px solid #fde047;"
            "color:#854d0e;font-size:13px;font-weight:600;margin-bottom:10px;'>"
            "⚠️ Running on <b>local ML model</b> — add GROQ_API_KEY to .env for AI upgrade</div>",
            unsafe_allow_html=True
        )

    st.markdown("""
    <div class="rk-welcome">
        <div class="rk-welcome-title">🛡️ Welcome to <span>Rakshak AI</span></div>
        <div class="rk-welcome-sub">Your smart campus safety companion. Report an emergency in seconds and let AI help classify, prioritize and route the alert to the appropriate response team.</div>
        <span class="rk-chip">🤖 AI Detection</span><span class="rk-chip">📍 Smart Location</span><span class="rk-chip">🚑 Responder Assignment</span><span class="rk-chip">📊 Live Tracking</span>
    </div>
    """, unsafe_allow_html=True)

    st.markdown("<div class='rk-section'>🚨 Report an Emergency</div>", unsafe_allow_html=True)
    st.markdown("<div class='rk-muted'>Give a clear description. Rakshak AI will analyze it automatically and create a response alert.</div>", unsafe_allow_html=True)
    st.markdown("""<div class='rk-sos'><div class='rk-sos-title'>⚡ Need immediate help?</div><div class='rk-sos-text'>Stay calm, enter the location and describe what is happening. Security responders will handle the next steps.</div></div>""", unsafe_allow_html=True)

    # ----------------------------------------------------------
    # FORM INPUTS
    # ----------------------------------------------------------

    st.markdown("<div class='rk-form-label'>👤 Student Name</div>", unsafe_allow_html=True)
    student_name = st.text_input(
        "Student Name",
        placeholder="Enter your name",
        label_visibility="collapsed"
    )

    st.markdown("<div class='rk-form-label'>📍 Select Emergency Location</div>", unsafe_allow_html=True)
    location = st.selectbox(
        "Select Emergency Location",
        list(campus_locations.keys()),
        label_visibility="collapsed"
    )

    incident_lat = campus_locations[location]["lat"]
    incident_lon = campus_locations[location]["lon"]

    st.markdown("<div class='rk-form-label'>📝 Describe the Emergency</div>", unsafe_allow_html=True)
    description = st.text_area(
        "Describe the Emergency",
        placeholder="Example: A student has fallen from a bike and is injured near the engineering block.",
        height=120,
        label_visibility="collapsed"
    )

    st.write("")
    analyze_button = st.button("🤖 ANALYZE & SEND ALERT", use_container_width=True)

    if analyze_button:
        if student_name.strip() == "":
            st.error("❌ Please enter your name.")
        elif description.strip() == "":
            st.error("❌ Please describe the emergency.")
        else:
            with st.spinner("🤖 Rakshak AI is analyzing the emergency…"):
                _process_and_display(
                    student_name, location, description,
                    incident_lat, incident_lon
                )

    _render_tracking_section()


# ----------------------------------------------------------
# INTERNAL HELPERS
# ----------------------------------------------------------

def _process_and_display(student_name, location, description, incident_lat, incident_lon):
    """Run AI analysis, save to DB, and display results."""

    # AI analysis (Groq or fallback)
    emergency_type, confidence, priority, risk_score, recommendation, groq_result = \
        smart_analyze(description, location)

    # Nearest responder & ETA
    responder, distance = find_nearest_responder(incident_lat, incident_lon)
    estimated_minutes = estimate_response_minutes(distance, priority)

    # Persist
    emergency_id = add_emergency(
        student_name, emergency_type, location, description,
        priority, responder, distance, confidence,
        risk_score, recommendation, estimated_minutes
    )
    st.session_state["last_emergency_id"] = emergency_id

    st.success("🚨 Emergency alert sent successfully!")
    st.info(f"🆔 Your Emergency ID is **#{emergency_id}**. You can track the response status below.")
    st.divider()

    # ── AI Analysis ──────────────────────────────────────────
    engine_label = "🤖 Groq AI Analysis" if groq_result else "🤖 AI Analysis (Local Model)"
    st.subheader(engine_label)

    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Emergency Type", emergency_type)
    with col2:
        st.metric("AI Confidence", f"{confidence:.1f}%")
    with col3:
        st.metric("Priority", priority)

    col4, col5 = st.columns(2)
    with col4:
        st.metric("Risk Score", f"{risk_score}/100")
    with col5:
        priority_colors = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🟢"}
        st.metric("Severity", f"{priority_colors.get(priority, '⚪')} {priority}")

    st.warning(f"🧠 **AI Recommended Action:** {recommendation}")

    # ── Groq Extended Report ─────────────────────────────────
    if groq_result:
        with st.expander("📋 Full Groq AI Report", expanded=True):
            summary = groq_result.get("summary", "")
            if summary:
                st.markdown(f"**📝 Situation Summary:**\n\n{summary}")

            steps = groq_result.get("immediate_steps", [])
            if steps:
                st.markdown("**⚡ Immediate Steps:**")
                for i, step in enumerate(steps, 1):
                    st.markdown(f"{i}. {step}")

    # ── Response Team ─────────────────────────────────────────
    st.subheader("🚑 Response Team")

    col1, col2 = st.columns(2)
    with col1:
        st.info(f"🚑 Nearest Responder: **{responder}**")
    with col2:
        st.info(f"📏 Distance: **{distance * 1000:.0f} meters**")

    eta_col1, eta_col2 = st.columns(2)
    with eta_col1:
        st.success(f"⏱️ **Estimated Help Time: ~{estimated_minutes} minutes**")
    with eta_col2:
        expected_by = datetime.now() + timedelta(minutes=estimated_minutes)
        st.info(f"🕐 **Expected Around: {expected_by.strftime('%I:%M %p')}**")

    st.caption("*ETA is an estimate based on responder distance and priority; actual response time may vary.*")

    # ── Map ───────────────────────────────────────────────────
    st.subheader("🗺️ Rakshak AI Campus Map")
    st.write("🔴 Emergency   🔵 Response Team   🟢 Campus Location")

    _render_map(location, incident_lat, incident_lon, responder,
                distance, emergency_type, priority)


def _render_map(location, incident_lat, incident_lon,
                responder_name, distance, emergency_type, priority):
    """Build and display the Folium map for the submitted emergency."""
    import requests

    campus_map = folium.Map(
        location=[incident_lat, incident_lon],
        zoom_start=17,
        control_scale=True
    )

    # Emergency marker
    folium.Marker(
        [incident_lat, incident_lon],
        popup=folium.Popup(
            f"<b>🚨 EMERGENCY</b><br>Location: {location}<br>"
            f"Type: {emergency_type}<br>Priority: {priority}",
            max_width=300
        ),
        tooltip="🚨 Emergency Location",
        icon=folium.Icon(color="red", icon="warning-sign")
    ).add_to(campus_map)

    # Responder marker
    responder_data = responders[responder_name]
    folium.Marker(
        [responder_data["lat"], responder_data["lon"]],
        popup=folium.Popup(
            f"<b>🚑 {responder_name}</b><br>Distance: {distance * 1000:.0f} meters",
            max_width=300
        ),
        tooltip="🚑 Response Team",
        icon=folium.Icon(color="blue", icon="plus")
    ).add_to(campus_map)

    # All other campus locations
    for place, data in campus_locations.items():
        if place != location:
            folium.Marker(
                [data["lat"], data["lon"]],
                popup=folium.Popup(
                    f"<b>📍 {place}</b><br>Category: {data['category']}",
                    max_width=300
                ),
                tooltip=f"📍 {place}",
                icon=folium.DivIcon(
                    html=f"""
                    <div style="font-size:12px;font-weight:bold;color:black;
                                background-color:white;padding:3px 6px;
                                border:1px solid black;border-radius:4px;
                                white-space:nowrap;box-shadow:0 1px 3px rgba(0,0,0,0.3);">
                        📍 {place}
                    </div>
                    """
                )
            ).add_to(campus_map)

    # Road route (OSRM) with straight-line fallback
    try:
        route_url = (
            "https://router.project-osrm.org/route/v1/driving/"
            f"{incident_lon},{incident_lat};"
            f"{responder_data['lon']},{responder_data['lat']}"
            "?overview=full&geometries=geojson"
        )
        route_response = requests.get(route_url, timeout=8)
        route_data = route_response.json()

        if route_data.get("code") == "Ok" and route_data.get("routes"):
            route = route_data["routes"][0]
            road_distance = route["distance"]
            road_time = route["duration"]
            route_points = [
                [lat, lon] for lon, lat in route["geometry"]["coordinates"]
            ]
            folium.PolyLine(
                route_points,
                tooltip=f"🚑 Road Route • {road_distance:.0f} m • ~{road_time / 60:.1f} min",
                popup=(
                    f"<b>🚑 Real Road Route</b><br>"
                    f"Distance: {road_distance:.0f} m<br>"
                    f"Estimated time: {road_time / 60:.1f} min"
                ),
                weight=6
            ).add_to(campus_map)
        else:
            raise RuntimeError("Road route not available")

    except Exception:
        folium.PolyLine(
            [[incident_lat, incident_lon],
             [responder_data["lat"], responder_data["lon"]]],
            tooltip="Approximate straight-line route",
            weight=4,
            dash_array="8, 8"
        ).add_to(campus_map)

    st_folium(campus_map, width=1000, height=550, returned_objects=[])


def _render_tracking_section():
    """Show live response-status tracker for the most recently submitted emergency."""
    import pandas as pd
    from database.db import get_emergencies

    if "last_emergency_id" not in st.session_state:
        return

    st.divider()
    st.subheader("📍 Track Your Emergency")

    track_id = st.session_state["last_emergency_id"]
    if st.button("🔄 Refresh Response Status", use_container_width=False):
        st.rerun()

    track_data = get_emergencies()
    track_row = track_data[track_data["id"] == track_id]

    if track_row.empty:
        return

    current = track_row.iloc[0]
    current_status = current["status"]

    status_steps = ["Pending", "Dispatched", "On the Way", "Arrived", "Resolved"]
    icons = {
        "Pending": "⏳", "Dispatched": "🚑",
        "On the Way": "🚗", "Arrived": "📍", "Resolved": "✅"
    }

    st.write(f"**Emergency #{track_id}** • Responder: **{current['responder']}**")

    if pd.notna(current.get("estimated_minutes")):
        eta_minutes = int(current["estimated_minutes"])
        report_time = pd.to_datetime(current["time"], errors="coerce")

        if current_status in ["Pending", "Dispatched", "On the Way"]:
            expected_time = (
                report_time + timedelta(minutes=eta_minutes)
                if pd.notna(report_time) else None
            )
            eta_text = f"~{eta_minutes} minutes"
            if expected_time is not None:
                eta_text += f" (around {expected_time.strftime('%I:%M %p')})"
            st.success(f"⏱️ **Estimated help arrival: {eta_text}**")
            st.caption("*This is an estimated response time, not a guaranteed arrival time.*")
        elif current_status == "Arrived":
            st.success("📍 **Help has arrived at your location.**")
        elif current_status == "Resolved":
            st.success("✅ **Your reported problem has been resolved.**")

    cols = st.columns(5)
    current_index = status_steps.index(current_status) if current_status in status_steps else 0

    for i, step in enumerate(status_steps):
        with cols[i]:
            if i <= current_index:
                st.success(f"{icons[step]} {step}")
            else:
                st.empty()

    status_messages = {
        "Pending":    ("warning", "Security team has received your alert and is preparing dispatch."),
        "Dispatched": ("info",    "Your response team has been dispatched."),
        "On the Way": ("info",    "Your response team is on the way."),
        "Arrived":    ("success", "Your response team has arrived."),
        "Resolved":   ("success", "Your emergency has been marked as resolved."),
    }
    fn_name, msg = status_messages.get(current_status, ("info", ""))
    getattr(st, fn_name)(msg)
