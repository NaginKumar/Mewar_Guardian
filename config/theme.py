# =========================================================
# MODERN UI THEME  –  Rakshak AI
# All CSS injected once from here to keep app.py clean.
# =========================================================

THEME_CSS = """
<style>
    /* LIGHT, CLEAN RAKSHAK AI THEME */
    .stApp {
        background: linear-gradient(135deg, #f5f9ff 0%, #eef5ff 55%, #ffffff 100%);
        color: #172554;
    }
    [data-testid="stHeader"] { background: rgba(255,255,255,0); }
    [data-testid="stSidebar"] {
        background: linear-gradient(180deg, #ffffff 0%, #f4f8ff 100%);
        border-right: 1px solid #dbe7f5;
    }
    [data-testid="stSidebar"] * { color: #1e3a5f !important; }

    .rk-hero {
        padding: 28px 30px;
        border-radius: 22px;
        background: linear-gradient(135deg, #eaf4ff, #f8fbff);
        border: 1px solid #d7e8fb;
        box-shadow: 0 10px 30px rgba(30, 64, 175, .08);
        margin-bottom: 22px;
    }
    .rk-brand { color:#123b73; font-size:36px; font-weight:800; letter-spacing:-.8px; margin:0; }
    .rk-brand span { color:#e63946; }
    .rk-sub { color:#52708f; margin-top:7px; font-size:15px; }
    .rk-online {
        display:inline-flex; align-items:center; gap:8px; margin-top:17px;
        padding:7px 13px; border-radius:999px; background:#ecfdf3;
        border:1px solid #bbf7d0; color:#15803d; font-size:13px;
    }
    .rk-dot { width:8px; height:8px; border-radius:50%; background:#22c55e; box-shadow:0 0 10px #86efac; }
    .rk-section { color:#173b69; font-size:22px; font-weight:750; margin:8px 0 5px; }
    .rk-muted { color:#607d9b; font-size:14px; }
    .rk-card {
        background:#ffffff; border:1px solid #dce8f5;
        border-radius:18px; padding:18px; box-shadow:0 8px 24px rgba(30,64,175,.07);
    }
    .rk-sos {
        padding:17px 20px; border-radius:16px; background:linear-gradient(135deg,#fff1f2,#ffe4e6);
        border:1px solid #fecdd3; margin:12px 0 20px;
    }
    .rk-sos-title {color:#b91c1c;font-size:18px;font-weight:800;}
    .rk-sos-text {color:#9f1239;font-size:13px;margin-top:3px;}
    .rk-footer { text-align:center; color:#7187a3; padding:24px 0 8px; font-size:12px; }
    .rk-form-label {
        color:#173b69 !important;
        font-size:20px !important;
        font-weight:800 !important;
        line-height:1.35 !important;
        margin:18px 0 8px !important;
        display:block !important;
        opacity:1 !important;
        text-shadow:none !important;
    }
    .rk-form-label::first-letter { font-size:21px; }

    div.stButton > button {
        border-radius:12px; font-weight:700; border:1px solid #cbdcf0;
        min-height:44px; transition:all .15s ease; background:#ffffff; color:#173b69 !important;
    }
    div.stButton > button:hover { transform:translateY(-1px); border-color:#2563eb; box-shadow:0 5px 15px rgba(37,99,235,.12); }

    .stMetric {
        background:#ffffff; border:1px solid #dce8f5;
        padding:12px 14px; border-radius:16px; box-shadow:0 6px 18px rgba(30,64,175,.06);
    }
    .stMetric * { color:#173b69 !important; }

    /* HIGH-CONTRAST FORM LABELS */
    .stTextInput label, .stTextArea label, .stSelectbox label,
    [data-testid="stWidgetLabel"], [data-testid="stWidgetLabel"] *,
    [data-testid="stWidgetLabel"] p {
        color:#173b69 !important;
        font-size:18px !important;
        font-weight:800 !important;
        opacity:1 !important;
        text-shadow:none !important;
    }
    .stTextInput input, .stTextArea textarea {
        background:#ffffff !important; color:#172554 !important;
        -webkit-text-fill-color:#172554 !important;
        border:2px solid #cbdcf0 !important; border-radius:12px !important;
        font-size:16px !important; font-weight:500 !important; opacity:1 !important;
    }
    .stTextInput input:focus, .stTextArea textarea:focus {
        border-color:#3b82f6 !important;
        box-shadow:0 0 0 3px rgba(59,130,246,.12) !important;
    }
    .stTextInput input::placeholder, .stTextArea textarea::placeholder {
        color:#6b829d !important; opacity:1 !important;
        -webkit-text-fill-color:#6b829d !important;
    }
    .stSelectbox [data-baseweb="select"] > div {
        background:#ffffff !important; color:#172554 !important;
        border:2px solid #cbdcf0 !important; border-radius:12px !important;
        min-height:48px !important; opacity:1 !important;
    }
    .stSelectbox [data-baseweb="select"] *, .stSelectbox [data-baseweb="select"] span,
    .stSelectbox [data-baseweb="select"] input {
        color:#172554 !important; -webkit-text-fill-color:#172554 !important; opacity:1 !important;
    }
    [data-baseweb="popover"], [data-baseweb="menu"], [data-baseweb="menu"] *, [role="option"] {
        background:#ffffff !important; color:#172554 !important;
        -webkit-text-fill-color:#172554 !important; opacity:1 !important;
    }
    .stMarkdown, .stText, p, label { color:#294766; }
    h1, h2, h3, h4 { color:#173b69 !important; }

    /* Emergency button */
    div.stButton > button[kind="primary"] {
        background:linear-gradient(90deg,#ef4444,#dc2626) !important;
        color:white !important; border:none !important;
    }
</style>
"""
