# =========================================================
# SECURITY DASHBOARD  –  Monitor, dispatch & resolve emergencies
# =========================================================

import pandas as pd
import streamlit as st

from database.db import get_emergencies, update_status


def render():
    """Render the full Security Dashboard page."""

    st.markdown("""<div class='rk-dashboard-hero'><div class='rk-live'>● LIVE SECURITY COMMAND CENTER</div><div class='rk-dashboard-title'>👮 Security Response Dashboard</div><div class='rk-muted'>Monitor, dispatch and resolve campus emergencies from one place.</div></div>""", unsafe_allow_html=True)

    data = get_emergencies()
    total = len(data)

    # ----------------------------------------------------------
    # STATUS COUNTS
    # ----------------------------------------------------------

    if total > 0:
        pending    = len(data[data["status"] == "Pending"])
        dispatched = len(data[data["status"] == "Dispatched"])
        on_way     = len(data[data["status"] == "On the Way"])
        arrived    = len(data[data["status"] == "Arrived"])
        resolved   = len(data[data["status"] == "Resolved"])
    else:
        pending = dispatched = on_way = arrived = resolved = 0

    # ----------------------------------------------------------
    # LIVE ALERT BANNER
    # ----------------------------------------------------------

    if pending > 0:
        latest_pending = data[data["status"] == "Pending"].iloc[0]
        st.markdown(
            f"""<div class='rk-alert-box'><div class='rk-alert-title'>🚨 LIVE EMERGENCY ALERT</div>"""
            f"""<div style='margin-top:7px;color:#ffe4e6;'>Emergency <b>#{latest_pending['id']}</b> reported by """
            f"""<b>{latest_pending['student_name']}</b> at <b>{latest_pending['location']}</b> """
            f"""• Priority: <b>{latest_pending['priority']}</b></div></div>""",
            unsafe_allow_html=True
        )

        alert_col1, alert_col2, alert_col3 = st.columns(3)
        with alert_col1:
            st.write(f"🤖 **Type:** {latest_pending['emergency_type']}")
        with alert_col2:
            st.write(f"🚑 **Responder:** {latest_pending['responder']}")
        with alert_col3:
            st.write(f"🕐 **Reported:** {latest_pending['time']}")

        st.warning("⚠️ Action required: dispatch the assigned response team.")

        # Play alarm sound for pending emergency
        st.markdown(
            """
            <audio autoplay loop>
                <source src="https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3" type="audio/mpeg">
            </audio>
            """,
            unsafe_allow_html=True
        )

    # ----------------------------------------------------------
    # CLICKABLE STATUS OVERVIEW CARDS
    # ----------------------------------------------------------

    st.markdown("<div class='rk-section'>📊 Emergency Overview</div>", unsafe_allow_html=True)
    metric_cols = st.columns(6)
    metric_data = [
        ("🚨 Total Emergencies", total,      "All"),
        ("⏳ Pending",           pending,    "Pending"),
        ("🚑 Dispatched",        dispatched, "Dispatched"),
        ("🚗 On the Way",        on_way,     "On the Way"),
        ("📍 Arrived",           arrived,    "Arrived"),
        ("✅ Resolved",          resolved,   "Resolved"),
    ]

    for col, (label, value, filter_value) in zip(metric_cols, metric_data):
        with col:
            if st.button(
                f"{label}\n\n{value}",
                key=f"metric_{filter_value.replace(' ', '_')}",
                use_container_width=True
            ):
                st.session_state["security_status_filter"] = filter_value
                st.rerun()

    st.caption("💡 Click any status card to instantly view the emergencies in that stage.")
    st.divider()

    # ----------------------------------------------------------
    # STATUS FILTER
    # ----------------------------------------------------------

    st.subheader("🔎 View Emergencies by Status")
    if "security_status_filter" not in st.session_state:
        st.session_state["security_status_filter"] = "All"

    status_filter = st.radio(
        "Select a status to view its emergency reports:",
        ["All", "Pending", "Dispatched", "On the Way", "Arrived", "Resolved"],
        horizontal=True,
        key="security_status_filter"
    )

    # ----------------------------------------------------------
    # ANALYTICS
    # ----------------------------------------------------------

    st.subheader("📊 Emergency Analytics")

    if total > 0:
        _render_analytics(data)
    else:
        st.info("📊 Analytics will appear after the first emergency is reported.")

    st.divider()

    # ----------------------------------------------------------
    # EMERGENCY LIST
    # ----------------------------------------------------------

    if total == 0:
        st.info("No emergencies reported yet.")
    else:
        st.subheader("📋 Emergency Reports")
        display_data = (
            data if status_filter == "All"
            else data[data["status"] == status_filter]
        )

        if display_data.empty:
            st.info(f"No emergencies are currently in **{status_filter}** status.")

        for _, row in display_data.iterrows():
            _render_emergency_card(row)


# ----------------------------------------------------------
# INTERNAL HELPERS
# ----------------------------------------------------------

def _render_analytics(data: pd.DataFrame):
    """Render performance metrics and bar charts."""
    analytics = data.copy()

    for time_col in ["time", "dispatch_time", "arrived_time", "resolved_time"]:
        if time_col in analytics.columns:
            analytics[time_col] = pd.to_datetime(analytics[time_col], errors="coerce")

    analytics["dispatch_minutes"]   = (analytics["dispatch_time"]  - analytics["time"]).dt.total_seconds() / 60
    analytics["arrival_minutes"]    = (analytics["arrived_time"]   - analytics["time"]).dt.total_seconds() / 60
    analytics["resolution_minutes"] = (analytics["resolved_time"]  - analytics["time"]).dt.total_seconds() / 60

    avg_dispatch   = analytics["dispatch_minutes"].dropna().mean()
    avg_arrival    = analytics["arrival_minutes"].dropna().mean()
    avg_resolution = analytics["resolution_minutes"].dropna().mean()

    a1, a2, a3 = st.columns(3)
    with a1:
        st.metric("⏱️ Avg Dispatch Time",   f"{avg_dispatch:.1f} min"   if pd.notna(avg_dispatch)   else "—")
    with a2:
        st.metric("🚑 Avg Arrival Time",    f"{avg_arrival:.1f} min"    if pd.notna(avg_arrival)    else "—")
    with a3:
        st.metric("✅ Avg Resolution Time", f"{avg_resolution:.1f} min" if pd.notna(avg_resolution) else "—")

    chart_col1, chart_col2 = st.columns(2)
    with chart_col1:
        st.markdown("**🚨 Emergencies by Type**")
        st.bar_chart(data["emergency_type"].value_counts())
    with chart_col2:
        st.markdown("**📍 Emergencies by Location**")
        st.bar_chart(data["location"].value_counts().head(10))

    st.markdown("**⚠️ Priority Distribution**")
    st.bar_chart(data["priority"].value_counts())

    chart_col3, chart_col4 = st.columns(2)
    with chart_col3:
        st.markdown("**🔄 Status Distribution**")
        st.bar_chart(data["status"].value_counts())
    with chart_col4:
        st.markdown("**🧠 Risk Score by Emergency**")
        risk_chart = data[["id", "risk_score"]].dropna().set_index("id")
        if not risk_chart.empty:
            st.bar_chart(risk_chart)

    csv_data = data.to_csv(index=False).encode("utf-8")
    st.download_button(
        "⬇️ Download Emergency Report (CSV)",
        data=csv_data,
        file_name="rakshak_emergency_report.csv",
        mime="text/csv"
    )


def _render_emergency_card(row):
    """Render a single emergency record with status controls."""
    st.markdown("---")
    st.markdown(f"### 🚨 Emergency #{row['id']}")

    col1, col2 = st.columns(2)

    with col1:
        st.write(f"👤 **Student:** {row['student_name']}")
        st.write(f"📍 **Location:** {row['location']}")
        st.write(f"🤖 **AI Type:** {row['emergency_type']}")
        st.write(f"⚠️ **Priority:** {row['priority']}")
        if pd.notna(row.get("risk_score")):
            st.write(f"🧠 **Risk Score:** {int(row['risk_score'])}/100")
        if pd.notna(row.get("ai_confidence")):
            st.write(f"🤖 **AI Confidence:** {float(row['ai_confidence']):.1f}%")

    with col2:
        st.write(f"🚑 **Responder:** {row['responder']}")
        st.write(f"📏 **Distance:** {row['distance'] * 1000:.0f} meters")
        if pd.notna(row.get("estimated_minutes")):
            st.write(f"⏱️ **Estimated Help Time:** ~{int(row['estimated_minutes'])} min")
        st.write(f"📌 **Status:** {row['status']}")
        st.write(f"🕐 **Reported:** {row['time']}")

        for field, label in [
            ("dispatch_time", "🚑 **Dispatched:**"),
            ("on_way_time",   "🚗 **On the Way:**"),
            ("arrived_time",  "📍 **Arrived:**"),
            ("resolved_time", "✅ **Resolved:**"),
        ]:
            if pd.notna(row.get(field)) and row.get(field):
                st.write(f"{label} {row[field]}")

    st.write(f"📝 **Description:** {row['description']}")
    if pd.notna(row.get("recommendation")) and row.get("recommendation"):
        st.info(f"🧠 **AI Response Recommendation:** {row['recommendation']}")

    # Status timeline hint
    st.markdown("**🔄 Response Flow:** Pending → Dispatched → On the Way → Arrived → Resolved")

    status = row["status"]
    status_hints = {
        "Pending":    ("warning", "⏳ Waiting for security team to dispatch the responder."),
        "Dispatched": ("info",    "🚑 Responder dispatched. Next: mark **On the Way**."),
        "On the Way": ("info",    "🚑 Responder is currently on the way to the emergency location."),
        "Arrived":    ("success", "📍 Responder has arrived at the emergency location."),
        "Resolved":   ("success", "✅ Emergency has been resolved."),
    }
    if status in status_hints:
        fn_name, msg = status_hints[status]
        getattr(st, fn_name)(msg)

    # Action buttons
    action_col1, action_col2 = st.columns(2)
    eid = row["id"]

    with action_col1:
        if status == "Pending":
            if st.button("🚑 Dispatch",      key=f"dispatch_{eid}", use_container_width=True):
                update_status(eid, "Dispatched")
                st.rerun()
        elif status == "Dispatched":
            if st.button("🚗 On the Way",    key=f"onway_{eid}",    use_container_width=True):
                update_status(eid, "On the Way")
                st.rerun()
        elif status == "On the Way":
            if st.button("📍 Mark Arrived",  key=f"arrived_{eid}",  use_container_width=True):
                update_status(eid, "Arrived")
                st.rerun()

    with action_col2:
        if status == "Arrived":
            if st.button("✅ Resolve",        key=f"resolve_{eid}",  use_container_width=True):
                update_status(eid, "Resolved")
                st.rerun()
