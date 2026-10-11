// ============================================================
// RAKSHAK AI - Main Student Interface JavaScript
// ============================================================

let campusLocations = [];
let currentEmergencyId = null;
let studentLat = null, studentLon = null;
let gpsWatchId = null;
let campusMap = null, campusMapInitialized = false;
let chatHistory = [];
let pendingEmergency = null;
let etaCountdownTimer = null;
let etaSeconds = 0;
let trackingMap = null;

document.addEventListener("DOMContentLoaded", () => {
  initTabs();
  loadLocations();
  checkAIStatus();
});

function checkAIStatus() {
  fetch("/api/status").then(r => r.json()).then(d => {
    const label = d.groq_available
      ? "Groq AI Active \u2022 " + d.locations_count + " Campus Locations"
      : "Local ML \u2022 " + d.locations_count + " Campus Locations";
    const el = document.getElementById("ai-engine-label");
    if (el) el.textContent = label;
    const cs = document.getElementById("chat-ai-status");
    if (cs) cs.textContent = d.groq_available ? "Groq AI Emergency Assistant \u2022 Online" : "Local ML Mode \u2022 Online";
  }).catch(() => {});
}

let audioCtx = null;
function playEmergencyBell() {
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (!audioCtx) audioCtx = new AudioContext();
    if (audioCtx.state === 'suspended') audioCtx.resume();
    
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = 'square';
    
    osc.frequency.setValueAtTime(880, audioCtx.currentTime); // Beep
    gain.gain.setValueAtTime(0, audioCtx.currentTime);
    gain.gain.linearRampToValueAtTime(0.5, audioCtx.currentTime + 0.05);
    gain.gain.setValueAtTime(0.5, audioCtx.currentTime + 0.2);
    gain.gain.linearRampToValueAtTime(0, audioCtx.currentTime + 0.25);
    
    osc.frequency.setValueAtTime(880, audioCtx.currentTime + 0.4); // Beep
    gain.gain.setValueAtTime(0, audioCtx.currentTime + 0.4);
    gain.gain.linearRampToValueAtTime(0.5, audioCtx.currentTime + 0.45);
    gain.gain.setValueAtTime(0.5, audioCtx.currentTime + 0.6);
    gain.gain.linearRampToValueAtTime(0, audioCtx.currentTime + 0.65);
    
    osc.frequency.setValueAtTime(880, audioCtx.currentTime + 0.8); // Beep
    gain.gain.setValueAtTime(0, audioCtx.currentTime + 0.8);
    gain.gain.linearRampToValueAtTime(0.5, audioCtx.currentTime + 0.85);
    gain.gain.setValueAtTime(0.5, audioCtx.currentTime + 1.0);
    gain.gain.linearRampToValueAtTime(0, audioCtx.currentTime + 1.05);
    
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start();
    osc.stop(audioCtx.currentTime + 1.1);
  } catch (e) {
    console.error("Audio API error:", e);
  }
}

// TABS
function initTabs() {
  document.querySelectorAll(".tab-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      const tabId = btn.dataset.tab;
      document.querySelectorAll(".tab-btn").forEach(b => b.classList.remove("active"));
      document.querySelectorAll(".tab-pane").forEach(p => p.classList.remove("active"));
      btn.classList.add("active");
      const pane = document.getElementById("tab-" + tabId);
      if (pane) pane.classList.add("active");
      if (tabId === "map" && !campusMapInitialized) setTimeout(initCampusMap, 100);
    });
  });
}

// LOCATIONS
function loadLocations() {
  fetch("/api/locations").then(r => r.json()).then(d => {
    campusLocations = d.locations;
    populateLocationSelect("location-select");
    populateLocationSelect("home-location");
  });
}

function populateLocationSelect(id) {
  const sel = document.getElementById(id);
  if (!sel) return;
  sel.innerHTML = campusLocations
    .map(l => `<option value="${l.name}" data-lat="${l.lat}" data-lon="${l.lon}">${l.name} (${l.category})</option>`)
    .join("");
  
  if (id === "home-location") {
    sel.addEventListener("change", updateSelectedLocationDisplay);
  }
}

function updateSelectedLocationDisplay() {
  const sel = document.getElementById("home-location");
  const disp = document.getElementById("home-gps-status");
  if (sel && disp && sel.options.length > 0) {
    const opt = sel.options[sel.selectedIndex];
    if (opt) {
      const lat = opt.getAttribute("data-lat");
      const lon = opt.getAttribute("data-lon");
      disp.innerHTML = `Manual Selection: <span style="color:#fbbf24">${opt.value}</span><br><span style="font-size:12px;font-weight:400">Lat: ${parseFloat(lat).toFixed(6)}, Lon: ${parseFloat(lon).toFixed(6)}</span>`;
      disp.style.color = "#e8edf7";
      // Clear GPS coordinates to enforce manual selection
      studentLat = parseFloat(lat);
      studentLon = parseFloat(lon);
    }
  }
}

function filterLocations(q) { filterLocSel("location-select", q); }
function filterReportLocations(q) { filterLocSel("report-location", q); }
function filterHomeLocations(q) { filterLocSel("home-location", q); }

function filterLocSel(id, q) {
  const sel = document.getElementById(id);
  if (!sel) return;
  const ql = q.toLowerCase();
  sel.innerHTML = campusLocations
    .filter(l => l.name.toLowerCase().includes(ql) || l.category.toLowerCase().includes(ql))
    .map(l => `<option value="${l.name}" data-lat="${l.lat}" data-lon="${l.lon}">${l.name} (${l.category})</option>`)
    .join("");
}

// GPS
function getGPSLocation() {
  const st1 = document.getElementById("gps-status");
  const st2 = document.getElementById("home-gps-status");
  
  if (!navigator.geolocation) { 
    if(st1) st1.textContent="GPS not supported."; 
    if(st2) st2.textContent="GPS not supported."; 
    return; 
  }
  if(st1) st1.textContent = "Getting GPS...";
  if(st2) st2.textContent = "Getting GPS...";
  
  navigator.geolocation.getCurrentPosition(pos => {
    studentLat = pos.coords.latitude; studentLon = pos.coords.longitude;
    const acc = Math.round(pos.coords.accuracy);
    if(st1) { st1.textContent = "GPS acquired (\u00b1" + acc + "m)"; st1.style.color="#86efac"; }
    if(st2) { st2.textContent = "GPS acquired (\u00b1" + acc + "m)"; st2.style.color="#86efac"; }
  }, () => {
    if(st1) { st1.textContent = "GPS denied. Select location manually."; st1.style.color="#fca5a5"; }
    if(st2) { st2.textContent = "GPS denied. Select location manually."; st2.style.color="#fca5a5"; }
  }, { enableHighAccuracy: true, timeout: 10000 });
}

function startGPSWatch() {
  if (!navigator.geolocation || gpsWatchId) return;
  gpsWatchId = navigator.geolocation.watchPosition(
    pos => { studentLat = pos.coords.latitude; studentLon = pos.coords.longitude; },
    () => {}, { enableHighAccuracy: true, timeout: 10000, maximumAge: 5000 }
  );
}

// CHAT
function getStudentName() {
  return (document.getElementById("global-name")?.value || "").trim();
}
function getStudentMobile() {
  return (document.getElementById("global-mobile")?.value || "").trim();
}
function getStudentEnrollment() {
  return (document.getElementById("global-enrollment")?.value || "").trim();
}

function sendQuick(msg) {
  const inp = document.getElementById("chat-input");
  if (inp) { inp.value = msg; }
  sendChat();
}

function autoResize(el) {
  el.style.height = "auto";
  el.style.height = Math.min(el.scrollHeight, 140) + "px";
}

function sendChat() {
  const input = document.getElementById("chat-input");
  if (!input) return;
  const message = input.value.trim();
  if (!message) return;

  input.value = ""; input.style.height = "44px";
  const sendBtn = document.getElementById("send-btn");
  if (sendBtn) sendBtn.disabled = true;

  appendUserMsg(message);
  appendTyping();
  chatHistory.push({ role: "user", content: message });

  fetch("/api/chat", {
    method: "POST", headers: {"Content-Type":"application/json"},
    body: JSON.stringify({ message, history: chatHistory.slice(-10), student_name: getStudentName() })
  })
  .then(r => r.json())
  .then(data => {
    removeTyping();
    if (sendBtn) sendBtn.disabled = false;
    chatHistory.push({ role: "assistant", content: data.message || "" });
    if (data.is_emergency) {
      renderEmergencyResponse(data);
    } else {
      appendAIMsg(data.message || "Namaste! Koi bhi samasya ho toh batao.");
    }
  })
  .catch(() => {
    removeTyping();
    if (sendBtn) sendBtn.disabled = false;
    appendAIMsg("Network error. Please try again.");
  });
}

function appendUserMsg(text) {
  const m = document.getElementById("chat-messages");
  const d = document.createElement("div");
  d.className = "msg msg-user";
  d.innerHTML = `<div class="msg-bubble">${escHtml(text)}</div><div class="msg-avatar">\ud83d\udc64</div>`;
  m.appendChild(d); m.scrollTop = m.scrollHeight;
}

function appendTyping() {
  const m = document.getElementById("chat-messages");
  const d = document.createElement("div");
  d.className = "msg msg-ai"; d.id = "typing-ind";
  d.innerHTML = `<div class="msg-avatar">\ud83d\udee1\ufe0f</div><div class="msg-bubble"><div class="typing-dots"><span></span><span></span><span></span></div></div>`;
  m.appendChild(d); m.scrollTop = m.scrollHeight;
}

function removeTyping() {
  const el = document.getElementById("typing-ind");
  if (el) el.remove();
}

function appendAIMsg(text, extra) {
  const m = document.getElementById("chat-messages");
  const d = document.createElement("div");
  d.className = "msg msg-ai";
  const fmt = text.replace(/\*\*(.*?)\*\*/g,"<strong>$1</strong>").replace(/\n/g,"<br>");
  d.innerHTML = `<div class="msg-avatar">\ud83d\udee1\ufe0f</div><div class="msg-bubble"><p>${fmt}</p>${extra||""}</div>`;
  m.appendChild(d); m.scrollTop = m.scrollHeight;
  return d;
}

function renderEmergencyResponse(data) {
  pendingEmergency = data;
  const priority = (data.priority || "MEDIUM").toUpperCase();
  const priCls = priority.toLowerCase();
  const typeCls = getTypeCls(data.emergency_type);
  const loc = data.detected_location;

  let extra = `<div class="emergency-detect-banner">
    <div class="edb-title">\u26a0\ufe0f Emergency Detected</div>
    <div class="edb-row">
      <span class="badge badge-${priCls}">${priority}</span>
      <span class="badge badge-${typeCls}">${data.emergency_type||"Emergency"}</span>
      ${data.risk_score!=null ? `<span class="badge" style="background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.1);color:#9aa5be">Risk: ${data.risk_score}/100</span>` : ""}
      ${loc ? `<span class="badge" style="background:rgba(6,182,212,0.1);border:1px solid rgba(6,182,212,0.2);color:#67e8f9">\ud83d\udccd ${loc}</span>` : ""}
    </div>`;

  if (data.safety_tips && data.safety_tips.length > 0) {
    extra += `<div style="font-size:12px;color:#fbbf24;margin:6px 0 8px">\ud83d\udca1 ${data.safety_tips[0]}</div>`;
  }

  if (data.should_sos || data.ask_sos) {
    const label = data.should_sos ? "\ud83d\udea8 SEND SOS NOW" : "\ud83d\udea8 Yes, Send SOS";
    extra += `<div class="edb-actions">
      <button class="btn btn-sos" onclick="confirmSOS()">${label}</button>
      <button class="btn btn-outline btn-sm" onclick="dismissBar()">Not an emergency</button>
    </div>`;
    showActionBar(data);
  }
  extra += `</div>`;
  appendAIMsg(data.message || "", extra);

  if (priority === "CRITICAL" && data.should_sos) {
    setTimeout(() => { if (pendingEmergency) confirmSOS(); }, 1000);
  }
}

function showActionBar(data) {
  const bar = document.getElementById("emergency-action-bar");
  if (!bar) return;
  const typeEl = document.getElementById("ea-type-badge");
  const locEl  = document.getElementById("ea-location-text");
  if (typeEl) { typeEl.className = "badge badge-" + getTypeCls(data.emergency_type); typeEl.textContent = data.emergency_type || "Emergency"; }
  if (locEl)  locEl.textContent = data.detected_location ? "\ud83d\udccd " + data.detected_location : "";
  bar.classList.remove("hidden");
}

function dismissBar() {
  const bar = document.getElementById("emergency-action-bar");
  if (bar) bar.classList.add("hidden");
  pendingEmergency = null;
  appendAIMsg("Theek hai. Agar koi aur zaroorat ho toh batao. Main yahaan hoon. \ud83d\udee1\ufe0f");
}
function dismissEmergencyBar() { dismissBar(); }

function getTypeCls(type) {
  if (!type) return "medium";
  const t = type.toLowerCase();
  if (t.includes("medical")) return "medical";
  if (t.includes("fire")) return "fire";
  if (t.includes("security")) return "security";
  if (t.includes("accident")) return "accident";
  return "medium";
}

// SOS & EMERGENCY
function confirmSOS() {
  const bar = document.getElementById("emergency-action-bar");
  if (bar) bar.classList.add("hidden");
  const emg = pendingEmergency;
  const name = getStudentName();
  const mobile = getStudentMobile();
  const enrollment = getStudentEnrollment();
  
  if (!name || name === "Student") { showToast("\u274c","Enter your name in Home tab.","critical"); return; }
  if (!/^[6-9]\d{9}$/.test(mobile)) { 
    showToast("\u274c Invalid Mobile", "Enter a valid 10-digit mobile number.", "critical"); 
    return; 
  }
  if (!enrollment) { showToast("\u274c","Enter your enrollment number in Home tab.","critical"); return; }
  if (!/^MUR\d{7,10}$/i.test(enrollment)) {
    showToast("❌ Invalid Enrollment", "Enrollment must be 'MUR' followed by 7-10 digits (e.g., MUR2500001).", "critical");
    return;
  }

  let location = "Main Campus Reference";
  let fallbackLat = null;
  let fallbackLon = null;
  if (emg && emg.detected_location) {
    location = emg.detected_location;
  } else {
    const selChat = document.getElementById("location-select");
    const selHome = document.getElementById("home-location");
    let activeSel = null;
    if (selChat && selChat.value) activeSel = selChat;
    else if (selHome && selHome.value) activeSel = selHome;
    
    if (activeSel) {
      location = activeSel.value;
      const opt = activeSel.options[activeSel.selectedIndex];
      if (opt) {
        fallbackLat = parseFloat(opt.getAttribute("data-lat"));
        fallbackLon = parseFloat(opt.getAttribute("data-lon"));
      }
    }
  }

  const finalLat = studentLat !== null ? studentLat : fallbackLat;
  const finalLon = studentLon !== null ? studentLon : fallbackLon;

  const lastUserMsg = chatHistory.filter(h => h.role === "user").slice(-1)[0];
  const description = lastUserMsg ? "[AI Chat] " + lastUserMsg.content : "SOS via AI Chat";

  createEmergency({
    student_name: name,
    mobile_number: getStudentMobile(),
    enrollment_number: getStudentEnrollment(),
    description, location,
    emergency_type: emg?.emergency_type || null,
    priority: emg?.priority || null,
    risk_score: emg?.risk_score || null,
    ai_confidence: emg?.confidence ? emg.confidence * 100 : null,
    student_lat: finalLat, student_lon: finalLon
  });
}

function triggerManualSOS() {
  if (!confirm("Send SOS? This will immediately alert campus security.")) return;
  const name = getStudentName();
  const mobile = getStudentMobile();
  const enrollment = getStudentEnrollment();
  
  if (!name || name === "Student") { showToast("\u274c","Enter your name in Home tab.","critical"); return; }
  if (!/^[6-9]\d{9}$/.test(mobile)) { 
    showToast("\u274c Invalid Mobile", "Enter a valid 10-digit mobile number.", "critical"); 
    return; 
  }
  if (!enrollment) { showToast("\u274c","Enter your enrollment number in Home tab.","critical"); return; }
  if (!/^MUR\d{7,10}$/i.test(enrollment)) {
    showToast("❌ Invalid Enrollment", "Enrollment must be 'MUR' followed by 7-10 digits (e.g., MUR2500001).", "critical");
    return;
  }
  const selChat = document.getElementById("location-select");
  const selHome = document.getElementById("home-location");
  let location = "Main Campus Reference";
  let fallbackLat = null;
  let fallbackLon = null;
  
  let activeSel = null;
  if (selChat && selChat.value) activeSel = selChat;
  else if (selHome && selHome.value) activeSel = selHome;
  
  if (activeSel) {
    location = activeSel.value;
    const opt = activeSel.options[activeSel.selectedIndex];
    if (opt) {
      fallbackLat = parseFloat(opt.getAttribute("data-lat"));
      fallbackLon = parseFloat(opt.getAttribute("data-lon"));
    }
  }
  
  const finalLat = studentLat !== null ? studentLat : fallbackLat;
  const finalLon = studentLon !== null ? studentLon : fallbackLon;
  
  createEmergency({
    student_name: name,
    mobile_number: getStudentMobile(),
    enrollment_number: getStudentEnrollment(),
    description: "Manual SOS - Emergency button pressed",
    location, student_lat: finalLat, student_lon: finalLon
  });
}

function createEmergency(payload) {
  fetch("/api/emergency", {
    method: "POST", headers: {"Content-Type":"application/json"},
    body: JSON.stringify(payload)
  })
  .then(r => r.json())
  .then(data => {
    if (data.success) {
      pendingEmergency = null;
      currentEmergencyId = data.emergency_id;
      startGPSWatch();
      showSOSOverlay(data);
      
      
      playEmergencyBell();

      showToast("🔔 SOS ALERT SENT", "Emergency #" + data.emergency_id + " - " + data.emergency_type, "critical");
      appendAIMsg(
        "🔔 **SOS ALERT SENT**\n\nEmergency ID: #" + data.emergency_id + "\nStudent: " + data.student_name + "\nEnrollment: " + data.enrollment_number + "\nMobile: " + data.mobile_number + "\nType: **" + data.emergency_type + "**\nPriority: **" + data.priority + "**\nResponder: **" + data.responder + "**\nETA: ~" + data.estimated_minutes + " minutes\nLocation: " + data.location + "\nStatus: PENDING\n\nCampus security has been alerted. Please stay safe."
      );
    } else {
      showToast("\u274c Failed", "SOS could not be sent. Call security directly.", "critical");
      appendAIMsg("\u26a0\ufe0f SOS failed. Please contact campus security directly or call 100.");
    }
  })
  .catch(() => {
    showToast("\u274c Network Error", "Please try again or contact security.", "critical");
  });
}

function showSOSOverlay(data) {
  const ov = document.getElementById("sos-overlay");
  const det = document.getElementById("sos-details");
  if (!ov || !det) return;

  det.innerHTML = `
    <div class="sos-details-grid">
      <div class="sos-detail-item"><div class="sos-detail-label">Emergency ID</div><div class="sos-detail-value">#${data.emergency_id}</div></div>
      <div class="sos-detail-item"><div class="sos-detail-label">Type</div><div class="sos-detail-value">${data.emergency_type}</div></div>
      <div class="sos-detail-item"><div class="sos-detail-label">Priority</div><div class="sos-detail-value"><span class="badge badge-${(data.priority||"medium").toLowerCase()}">${data.priority}</span></div></div>
      <div class="sos-detail-item"><div class="sos-detail-label">Responder</div><div class="sos-detail-value">${data.responder}</div></div>
    </div>`;

  const locEl = document.getElementById("sos-location");
  const statusEl = document.getElementById("sos-status");
  if (locEl) locEl.textContent = data.location;
  if (statusEl) { statusEl.textContent = "Pending"; statusEl.className = "badge badge-pending"; }

  etaSeconds = data.estimated_minutes * 60;
  updateETADisplay();
  if (etaCountdownTimer) clearInterval(etaCountdownTimer);
  etaCountdownTimer = setInterval(() => {
    if (etaSeconds > 0) { etaSeconds--; updateETADisplay(); }
    else { const etaEl = document.getElementById("sos-eta"); if(etaEl) etaEl.textContent = "ARRIVED"; clearInterval(etaCountdownTimer); }
  }, 1000);

  ov.classList.remove("hidden");
}

function updateETADisplay() {
  const el = document.getElementById("sos-eta");
  if (!el) return;
  const m = Math.floor(etaSeconds / 60), s = etaSeconds % 60;
  el.textContent = String(m).padStart(2,"0") + " min " + String(s).padStart(2,"0") + " sec";
}

function closeSOSOverlay() {
  const ov = document.getElementById("sos-overlay");
  if (ov) ov.classList.add("hidden");
}

// REPORT TAB
function submitReport() {
  const name = getStudentName();
  const mobile = getStudentMobile();
  const enrollment = getStudentEnrollment();
  const desc = (document.getElementById("report-desc")?.value || "").trim();
  const typeSel = document.getElementById("report-type");
  const emergency_type = typeSel ? typeSel.value : "";

  const selHome = document.getElementById("home-location");
  let location = "Main Campus Reference";
  let fallbackLat = null;
  let fallbackLon = null;
  
  if (selHome && selHome.value) {
    location = selHome.value;
    const opt = selHome.options[selHome.selectedIndex];
    if (opt) {
      fallbackLat = parseFloat(opt.getAttribute("data-lat"));
      fallbackLon = parseFloat(opt.getAttribute("data-lon"));
    }
  }
  
  const finalLat = studentLat !== null ? studentLat : fallbackLat;
  const finalLon = studentLon !== null ? studentLon : fallbackLon;

  if (!name) { showToast("\u274c","Enter your name.","critical"); return; }
  if (!/^[6-9]\d{9}$/.test(mobile)) { 
    showToast("\u274c Invalid Mobile", "Enter a valid 10-digit mobile number.", "critical"); 
    return; 
  }
  if (!enrollment) { showToast("\u274c","Enter your enrollment number.","critical"); return; }
  if (!/^MUR\d{7,10}$/i.test(enrollment)) {
    showToast("❌ Invalid Enrollment", "Enrollment must be 'MUR' followed by 7-10 digits (e.g., MUR2500001).", "critical");
    return;
  }
  if (!desc) { showToast("\u274c","Describe the emergency.","critical"); return; }
  if (!location) { showToast("\u274c","Select a location.","critical"); return; }

  const btn = document.querySelector("#tab-home .btn-primary");
  if (btn) { btn.disabled = true; btn.textContent = "Analyzing..."; }

  fetch("/api/emergency", {
    method: "POST", headers: {"Content-Type":"application/json"},
    body: JSON.stringify({ 
      student_name: name, mobile_number: mobile, enrollment_number: enrollment,
      description: desc, location, emergency_type,
      student_lat: finalLat, student_lon: finalLon 
    })
  })
  .then(r => r.json())
  .then(data => {
    if (btn) { btn.disabled = false; btn.textContent = "\ud83e\udd16 ANALYZE & SEND ALERT"; }
    if (data.success) {
      currentEmergencyId = data.emergency_id;
      showReportResult(data);
      showToast("\ud83d\udea8 Alert Sent", "Emergency #" + data.emergency_id, "critical");
    }
  })
  .catch(() => {
    if (btn) { btn.disabled = false; btn.textContent = "\ud83e\udd16 ANALYZE & SEND ALERT"; }
    showToast("\u274c Failed", "Please try again.", "critical");
  });
}

function showReportResult(data) {
  const el = document.getElementById("report-result");
  if (!el) return;
  const p = data.priority || "MEDIUM";

  el.className = "report-result success-card";
  el.innerHTML = `
    <div class="report-result-title">\ud83d\udea8 Emergency Alert Sent!</div>
    <div class="result-grid">
      <div class="result-item"><div class="result-label">Emergency ID</div><div class="result-value">#${data.emergency_id}</div></div>
      <div class="result-item"><div class="result-label">Type</div><div class="result-value"><span class="badge badge-${getTypeCls(data.emergency_type)}">${data.emergency_type}</span></div></div>
      <div class="result-item"><div class="result-label">Priority</div><div class="result-value"><span class="badge badge-${p.toLowerCase()}">${p}</span></div></div>
      <div class="result-item"><div class="result-label">Risk Score</div><div class="result-value">${data.risk_score}/100</div></div>
      <div class="result-item"><div class="result-label">Responder</div><div class="result-value">${data.responder}</div></div>
      <div class="result-item"><div class="result-label">AI Confidence</div><div class="result-value">${parseFloat(data.ai_confidence||0).toFixed(1)}%</div></div>
    </div>
    <div class="eta-display">
      <div class="eta-label">Estimated Response Time</div>
      <div class="eta-time" id="rpt-eta">${String(data.estimated_minutes).padStart(2,"0")}:00</div>
      <div class="eta-distance">Distance: ${(data.distance_m/1000).toFixed(2)} km</div>
    </div>
    ${data.recommendation ? `<div style="margin-top:12px;padding:12px;background:rgba(249,115,22,0.08);border-radius:10px;border:1px solid rgba(249,115,22,0.2);font-size:13px;color:#fdba74">\ud83d\udca1 ${data.recommendation}</div>` : ""}
    <button class="btn btn-outline" style="margin-top:16px;width:100%" onclick="switchToTrack(${data.emergency_id})">\ud83d\udccd Track This Emergency</button>
  `;
  el.classList.remove("hidden");

  let secs = data.estimated_minutes * 60;
  const timer = document.getElementById("rpt-eta");
  const iv = setInterval(() => {
    if (secs <= 0 || !timer) { clearInterval(iv); return; }
    secs--;
    const m2 = Math.floor(secs/60), s2 = secs%60;
    timer.textContent = String(m2).padStart(2,"0") + ":" + String(s2).padStart(2,"0");
  }, 1000);
}

function switchToTrack(id) {
  const inp = document.getElementById("track-id");
  if (inp) inp.value = id;
  const btn = document.querySelector('[data-tab="track"]');
  if (btn) btn.click();
  setTimeout(trackEmergency, 100);
}

// TRACKING
let trackPollInterval = null;

function trackEmergency(isSilent = false) {
  const id = parseInt(document.getElementById("track-id")?.value || 0);
  if (!id) { 
    if (!isSilent) showToast("\u274c","Enter a valid emergency ID.","critical"); 
    return; 
  }

  fetch("/api/emergency/" + id)
    .then(r => r.json())
    .then(data => {
      if (data.error) {
        if (trackPollInterval) clearInterval(trackPollInterval);
        const el = document.getElementById("track-result");
        if (el && !isSilent) el.innerHTML = `<p class="error-msg">Emergency #${id} not found.</p>`;
        return;
      }
      renderTrackResult(data);
      
      // Start live polling if not already running and not resolved
      if (data.status !== "Resolved") {
        if (!trackPollInterval) {
          trackPollInterval = setInterval(() => trackEmergency(true), 10000);
        }
      } else {
        if (trackPollInterval) {
          clearInterval(trackPollInterval);
          trackPollInterval = null;
        }
      }
    })
    .catch(() => {
      if (!isSilent) showToast("\u274c","Failed to load emergency.","critical");
    });
}

function renderTrackResult(data) {
  const steps = ["Pending","Dispatched","On the Way","Arrived","Resolved"];
  const icons = {"Pending":"\u23f3","Dispatched":"\ud83d\ude91","On the Way":"\ud83d\ude97","Arrived":"\ud83d\udccd","Resolved":"\u2705"};
  const curIdx = steps.indexOf(data.status);

  const timeline = steps.map((s,i) => {
    const cls = i < curIdx ? "done" : i === curIdx ? "active" : "";
    return `<div class="status-step"><div class="step-dot ${cls}">${icons[s]}</div><div class="step-label ${cls}">${s}</div></div>`;
  }).join("");

  const p = data.priority || "MEDIUM";
  const stMap = {"Pending":"pending","Dispatched":"dispatched","On the Way":"onway","Arrived":"arrived","Resolved":"resolved"};
  const stCls = stMap[data.status] || "pending";

  let etaInfo = "";
  if (data.status !== "Resolved" && data.status !== "Arrived" && data.estimated_minutes) {
    etaInfo = `<div class="eta-display" style="margin-top:16px"><div class="eta-label">Estimated Response</div><div class="eta-time" id="track-eta">${String(data.estimated_minutes).padStart(2,"0")}:00</div></div>`;
  } else if (data.status === "Arrived") {
    etaInfo = `<div style="padding:12px;background:rgba(34,197,94,0.1);border:1px solid rgba(34,197,94,0.3);border-radius:10px;color:#86efac;font-weight:700;text-align:center;margin-top:12px">\ud83d\udccd Help has arrived!</div>`;
  } else if (data.status === "Resolved") {
    etaInfo = `<div style="padding:12px;background:rgba(107,114,128,0.1);border:1px solid rgba(107,114,128,0.3);border-radius:10px;color:#9ca3af;font-weight:700;text-align:center;margin-top:12px">\u2705 Emergency Resolved</div>`;
  }

  const el = document.getElementById("track-result");
  if (!el) return;
  el.innerHTML = `
    <div style="background:var(--card);border:1px solid var(--border);border-radius:16px;padding:20px;margin-top:16px">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;flex-wrap:wrap;gap:8px">
        <div style="font-size:18px;font-weight:800">Emergency #${data.id}</div>
        <div style="display:flex;gap:8px"><span class="badge badge-${p.toLowerCase()}">${p}</span><span class="badge badge-${stCls}">${data.status}</span></div>
      </div>
      <div class="status-timeline">${timeline}</div>
      <div class="result-grid" style="margin-top:16px">
        <div class="result-item"><div class="result-label">Type</div><div class="result-value">${data.emergency_type}</div></div>
        <div class="result-item"><div class="result-label">Location</div><div class="result-value">${data.location}</div></div>
        <div class="result-item"><div class="result-label">Responder</div><div class="result-value">${data.responder||"-"}</div></div>
        <div class="result-item"><div class="result-label">Reported</div><div class="result-value">${fmtTime(data.time)}</div></div>
      </div>
      ${etaInfo}
      <button class="btn btn-outline" style="margin-top:12px;width:100%" onclick="trackEmergency()">\ud83d\udd04 Refresh Status</button>
    </div>`;

  if (data.status !== "Resolved" && data.status !== "Arrived" && data.estimated_minutes) {
    if (window.trackInterval) clearInterval(window.trackInterval);
    
    // Attempt to calculate time passed since reported/dispatched to give a more accurate real-time countdown
    let startTime = data.time;
    if (data.dispatch_time) startTime = data.dispatch_time;
    if (data.on_way_time) startTime = data.on_way_time;
    
    let elapsedSecs = 0;
    if (startTime) {
      try {
        elapsedSecs = Math.floor((Date.now() - new Date(startTime).getTime()) / 1000);
        if (elapsedSecs < 0) elapsedSecs = 0;
      } catch (e) {}
    }
    
    let secs = (data.estimated_minutes * 60) - elapsedSecs;
    if (secs < 0) secs = 0;
    
    const timer = document.getElementById("track-eta");
    if (timer) {
      const updateTimer = () => {
        if (secs <= 0) {
          timer.textContent = "ARRIVING...";
          if (window.trackInterval) clearInterval(window.trackInterval);
          return;
        }
        const m = Math.floor(secs / 60);
        const s = secs % 60;
        timer.textContent = String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
        secs--;
      };
      updateTimer();
      window.trackInterval = setInterval(updateTimer, 1000);
    }
  }

  if (data.location) {
    const trackMap = document.getElementById("track-map");
    if (trackMap) {
      trackMap.classList.remove("hidden");
      setTimeout(() => initTrackMap(data), 200);
    }
  }
}

function initTrackMap(emgData) {
  const el = document.getElementById("track-map");
  if (!el) return;
  el.style.height = "350px"; el.style.borderRadius = "14px"; el.style.overflow = "hidden";
  if (trackingMap) { trackingMap.remove(); trackingMap = null; }

  const loc = campusLocations.find(l => l.name === emgData.location);
  if (!loc) return;

  trackingMap = L.map("track-map").setView([loc.lat, loc.lon], 17);
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { attribution: "\u00a9 OpenStreetMap" }).addTo(trackingMap);

  L.circleMarker([loc.lat, loc.lon], { radius:12, fillColor:"#ef4444", color:"#fff", weight:2, fillOpacity:1 })
    .addTo(trackingMap).bindPopup(`<b>\ud83d\udea8 ${emgData.location}</b>`);

  fetch("/api/responders").then(r => r.json()).then(rd => {
    const resp = rd.responders.find(r => r.name === emgData.responder);
    if (!resp) return;
    L.circleMarker([resp.lat, resp.lon], { radius:10, fillColor:"#3b82f6", color:"#fff", weight:2, fillOpacity:1 })
      .addTo(trackingMap).bindPopup(`<b>\ud83d\ude91 ${resp.name}</b>`);

    fetch(`/api/route?from_lat=${resp.lat}&from_lon=${resp.lon}&to_lat=${loc.lat}&to_lon=${loc.lon}`)
      .then(r => r.json()).then(rd2 => {
        if (rd2.code === "Ok" && rd2.routes) {
          const pts = rd2.routes[0].geometry.coordinates.map(c => [c[1],c[0]]);
          L.polyline(pts, { color:"#3b82f6", weight:4, opacity:0.8 }).addTo(trackingMap);
        } else {
          L.polyline([[resp.lat,resp.lon],[loc.lat,loc.lon]], { color:"#3b82f6", weight:3, dashArray:"8,6" }).addTo(trackingMap);
        }
      }).catch(() => {
        L.polyline([[resp.lat,resp.lon],[loc.lat,loc.lon]], { color:"#3b82f6", weight:3, dashArray:"8,6" }).addTo(trackingMap);
      });
  });
}

// CAMPUS MAP
function initCampusMap() {
  campusMapInitialized = true;
  const el = document.getElementById("campus-map");
  if (!el) return;
  campusMap = L.map("campus-map").setView([25.033, 74.6359], 17);
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { attribution: "\u00a9 OpenStreetMap" }).addTo(campusMap);

  const catColors = {
    "Hostel":"#a855f7","Academic":"#3b82f6","Medical":"#ef4444","Food":"#eab308",
    "Security":"#f97316","Sports":"#22c55e","Facility":"#06b6d4","Entry":"#14b8a6",
    "Parking":"#8b5cf6","Reference":"#9ca3af","University":"#f59e0b","Religious":"#ec4899",
    "Shopping":"#f59e0b","Utility":"#6b7280"
  };

  campusLocations.forEach(loc => {
    const color = catColors[loc.category] || "#9ca3af";
    L.circleMarker([loc.lat, loc.lon], { radius:8, fillColor:color, color:"#fff", weight:2, fillOpacity:0.9 })
      .addTo(campusMap)
      .bindPopup(`<div style="min-width:140px"><b>\ud83d\udccd ${loc.name}</b><br><small>${loc.category}${loc.verified?" \u2705":""}</small></div>`)
      .bindTooltip(loc.name, { permanent:false, direction:"top" });
  });

  fetch("/api/responders").then(r => r.json()).then(rd => {
    const cols = {"Medical Team":"#3b82f6","Fire Response Team":"#ef4444","Security Team":"#f97316"};
    rd.responders.forEach(resp => {
      L.circleMarker([resp.lat, resp.lon], { radius:11, fillColor:cols[resp.name]||"#fff", color:"#fff", weight:3, fillOpacity:1 })
        .addTo(campusMap).bindPopup(`<b>\ud83d\ude91 ${resp.name}</b>`).bindTooltip(resp.name);
    });
  });
}

// UTILITIES
function clearChat() {
  chatHistory = [];
  pendingEmergency = null;
  const bar = document.getElementById("emergency-action-bar");
  if (bar) bar.classList.add("hidden");
  const msgs = document.getElementById("chat-messages");
  if (msgs) msgs.innerHTML = `<div class="msg msg-ai"><div class="msg-avatar">\ud83d\udee1\ufe0f</div><div class="msg-bubble"><p>Chat cleared. Namaste! Main Rakshak AI hoon. Koi bhi emergency ke baare mein batao.</p></div></div>`;
}

function showToast(title, msg, type) {
  const cont = document.getElementById("toast-container");
  if (!cont) return;
  const icons = { critical:"\ud83d\udea8", success:"\u2705", info:"\u2139\ufe0f" };
  const t = document.createElement("div");
  t.className = "toast toast-" + type;
  t.innerHTML = `<div class="toast-icon">${icons[type]||"\ud83d\udd14"}</div><div class="toast-content"><div class="toast-title">${title}</div><div class="toast-msg">${msg}</div></div>`;
  cont.appendChild(t);
  setTimeout(() => { t.classList.add("fade-out"); setTimeout(() => t.remove(), 300); }, 4000);
}

function escHtml(s) { const d = document.createElement("div"); d.textContent = s; return d.innerHTML; }

function fmtTime(s) {
  if (!s) return "-";
  try { return new Date(s).toLocaleTimeString("en-IN", { hour:"2-digit", minute:"2-digit" }); }
  catch { return s; }
}
