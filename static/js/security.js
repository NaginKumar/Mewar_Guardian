// ============================================================
// RAKSHAK AI - Security Dashboard JavaScript
// ============================================================

let allEmergencies = [];
let currentFilter = "All";
let selectedEmgId = null;
let secMap = null;
let charts = {};
let notifCount = 0;
let notifications = [];
let eventSource = null;
let soundEnabled = true;
let lastSeenEmergencyId = 0;
let audioCtx = null;

function playEmergencyBell() {
  if (!soundEnabled) return;
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

function toggleSound() {
  soundEnabled = !soundEnabled;
  const btn = document.getElementById("sound-toggle-btn");
  if (btn) btn.innerHTML = soundEnabled ? "🔊 Alert Sound ON" : "🔇 Alert Sound OFF";
  
  if (soundEnabled) {
    try {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!audioCtx) audioCtx = new AudioContext();
      if (audioCtx.state === 'suspended') audioCtx.resume();
    } catch(e) {}
  }
}

document.addEventListener("DOMContentLoaded", () => {
  initClock();
  initSSE();
  loadEmergencies();
  loadAnalytics();
  initMap();
  setInterval(loadEmergencies, 30000);
  setInterval(loadAnalytics, 60000);
  requestNotifPermission();
});

function switchSecPage(pageId) {
  document.getElementById("page-live").style.display = pageId === "live" ? "block" : "none";
  document.getElementById("page-analytics").style.display = pageId === "analytics" ? "block" : "none";
  
  const pageMap = document.getElementById("page-map");
  if (pageMap) {
    pageMap.style.display = pageId === "map" ? "block" : "none";
    if (pageId === "map" && secMap) {
      setTimeout(() => secMap.invalidateSize(), 100);
    }
  }

  document.querySelectorAll(".sec-tab").forEach(tab => {
    // Exact match or includes is tricky, let's use exact data-id if possible, but includes works for now
    tab.classList.toggle("active", tab.textContent.toLowerCase().includes(pageId));
  });
}

// CLOCK
function initClock() {
  function tick() {
    const el = document.getElementById("live-clock");
    if (el) el.textContent = new Date().toLocaleString("en-IN", { dateStyle:"short", timeStyle:"medium" });
  }
  tick(); setInterval(tick, 1000);
}

// SSE
function initSSE() {
  if (eventSource) eventSource.close();
  eventSource = new EventSource("/api/stream");

  eventSource.onopen = () => {
    const el = document.getElementById("stream-status");
    if (el) { el.textContent = "Live \u2022 Real-time"; el.style.color = "#86efac"; }
  };

  eventSource.onmessage = (e) => {
    try {
      const data = JSON.parse(e.data);
      if (data.type === "new_emergency") {
        handleNewEmergency(data);
      } else if (data.type === "status_update") {
        handleStatusUpdate(data);
      }
    } catch (err) {}
  };

  eventSource.onerror = () => {
    const el = document.getElementById("stream-status");
    if (el) { el.textContent = "Reconnecting..."; el.style.color = "#fbbf24"; }
    setTimeout(initSSE, 5000);
  };
}

function handleNewEmergency(data) {
  if (data.id > lastSeenEmergencyId) {
    lastSeenEmergencyId = data.id;
  } else {
    return; // Ignore if we've already seen it or it's an old emergency
  }

  addNotification(data);
  loadEmergencies();
  loadAnalytics();

  if (data.priority === "CRITICAL" || data.priority === "HIGH") {
    const banner = document.getElementById("critical-banner");
    if (banner) {
      banner.classList.remove("hidden");
      setTimeout(() => banner.classList.add("hidden"), 8000);
    }
    showToast("\ud83d\udea8 NEW EMERGENCY", data.emergency_type + " at " + data.location, "critical");
    sendBrowserNotif("\ud83d\udea8 " + data.emergency_type + " - " + data.priority, data.location);
    if (soundEnabled) {
      playEmergencyBell();
    }
  } else {
    showToast("\ud83d\udd14 New Emergency", data.emergency_type + " at " + data.location, "info");
    if (soundEnabled) {
      playEmergencyBell();
    }
  }
}

function handleStatusUpdate(data) {
  loadEmergencies();
  if (selectedEmgId === data.id) {
    setTimeout(() => selectEmergency(data.id), 500);
  }
}

// EMERGENCIES
function loadEmergencies() {
  fetch("/api/emergencies").then(r => r.json()).then(d => {
    allEmergencies = d.emergencies || [];
    if (allEmergencies.length > 0 && lastSeenEmergencyId === 0) {
      lastSeenEmergencyId = Math.max(...allEmergencies.map(e => e.id));
    }
    updateMetrics();
    renderList();
  }).catch(() => {});
}

function updateMetrics() {
  const total      = allEmergencies.length;
  const pending    = allEmergencies.filter(e => e.status === "Pending").length;
  const dispatched = allEmergencies.filter(e => e.status === "Dispatched").length;
  const onway      = allEmergencies.filter(e => e.status === "On the Way").length;
  const arrived    = allEmergencies.filter(e => e.status === "Arrived").length;
  const resolved   = allEmergencies.filter(e => e.status === "Resolved").length;

  setText("m-total", total);
  setText("m-pending", pending);
  setText("m-dispatched", dispatched);
  setText("m-onway", onway);
  setText("m-arrived", arrived);
  setText("m-resolved", resolved);
}

function setText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

function filterStatus(status) {
  currentFilter = status;
  document.querySelectorAll(".ftab").forEach(t => {
    t.classList.toggle("active", t.dataset.filter === status);
  });
  renderList();
}

function filterBySearch() {
  renderList();
}

function renderList() {
  const container = document.getElementById("emergency-list");
  if (!container) return;

  let filtered = currentFilter === "All"
    ? allEmergencies
    : allEmergencies.filter(e => e.status === currentFilter);

  const searchInput = document.getElementById("search-input");
  if (searchInput && searchInput.value) {
    const q = searchInput.value.toLowerCase();
    filtered = filtered.filter(e => 
      (e.student_name || "").toLowerCase().includes(q) ||
      (e.mobile_number || "").toLowerCase().includes(q) ||
      (e.enrollment_number || "").toLowerCase().includes(q) ||
      String(e.id).includes(q) ||
      (e.location || "").toLowerCase().includes(q) ||
      (e.emergency_type || "").toLowerCase().includes(q)
    );
  }

  if (filtered.length === 0) {
    container.innerHTML = `<div class="loading-msg">No emergencies in this category.</div>`;
    return;
  }

  // Sorting: Unresolved CRITICAL > Unresolved HIGH > Unresolved MEDIUM/LOW > Resolved
  // And older unresolved should not be forgotten (sorted by ID or time descending within priority)
  filtered.sort((a, b) => {
    const isResA = a.status === "Resolved" ? 1 : 0;
    const isResB = b.status === "Resolved" ? 1 : 0;
    if (isResA !== isResB) return isResA - isResB; // Unresolved first
    
    const pVal = { "CRITICAL": 4, "HIGH": 3, "MEDIUM": 2, "LOW": 1 };
    const pA = pVal[a.priority] || 0;
    const pB = pVal[b.priority] || 0;
    if (pA !== pB) return pB - pA; // Higher priority first
    
    // Within same priority, sort by ID descending (newest first, though prompt says older not forgotten, descending is standard for dashboards to see newest incidents)
    return b.id - a.id; 
  });

  container.innerHTML = filtered.map(e => renderEmgCard(e)).join("");
}

function renderEmgCard(e) {
  const p = (e.priority || "LOW").toLowerCase();
  const stMap = {"Pending":"pending","Dispatched":"dispatched","On the Way":"onway","Arrived":"arrived","Resolved":"resolved"};
  const stCls = stMap[e.status] || "pending";
  const typCls = getTypeCls(e.emergency_type);
  const selected = selectedEmgId === e.id ? " selected" : "";
  const timeAgo = fmtTimeAgo(e.time);

  return `
    <div class="emg-card priority-${p}${selected}" onclick="selectEmergency(${e.id})" id="emg-card-${e.id}">
      <div class="emg-card-top">
        <div class="emg-card-id">#${e.id}</div>
        <div class="emg-card-time">${timeAgo}</div>
      </div>
      <div class="emg-card-title">${e.emergency_type || "Emergency"}</div>
      <div class="emg-card-badges">
        <span class="badge badge-${p}">${e.priority || "LOW"}</span>
        <span class="badge badge-${stCls}">${e.status}</span>
      </div>
      <div class="emg-card-loc">\ud83d\udccd ${e.location || "-"}</div>
      <div class="emg-card-student" style="display:flex; flex-direction:column; gap:2px; margin-top:8px;">
        <div>\ud83d\udc64 ${e.student_name || "Anonymous"}</div>
        <div style="font-size:11px; color:#9ca3af;">Enrollment: ${e.enrollment_number || "-"}</div>
        <div style="font-size:11px; color:#9ca3af;">Mobile: ${e.mobile_number || "-"}</div>
      </div>
    </div>`;
}

// DETAIL VIEW
function selectEmergency(id) {
  selectedEmgId = id;
  document.querySelectorAll(".emg-card").forEach(c => c.classList.remove("selected"));
  const card = document.getElementById("emg-card-" + id);
  if (card) card.classList.add("selected");

  fetch("/api/emergency/" + id).then(r => r.json()).then(renderDetail).catch(() => {});
}

function renderDetail(e) {
  const panel = document.getElementById("detail-panel");
  if (!panel) return;

  const p = (e.priority || "LOW").toLowerCase();
  const stMap = {"Pending":"pending","Dispatched":"dispatched","On the Way":"On the Way","Arrived":"arrived","Resolved":"resolved"};
  const stCls = stMap[e.status] || "pending";

  const steps = ["Pending","Dispatched","On the Way","Arrived","Resolved"];
  const curIdx = steps.indexOf(e.status);
  const statusFlow = steps.map((s,i) => {
    const cls = i < curIdx ? "done" : i === curIdx ? "current" : "";
    return `<span class="sf-step ${cls}">${s}</span>${i < steps.length-1 ? '<span class="sf-arrow">\u2192</span>' : ""}`;
  }).join("");

  let actions = "";
  const eid = e.id;
  if (e.status === "Pending") {
    actions += `<button class="btn btn-dispatch" onclick="updateStatus(${eid},'Dispatched')">\ud83d\ude91 DISPATCH</button>`;
  } else if (e.status === "Dispatched") {
    actions += `<button class="btn btn-onway" onclick="updateStatus(${eid},'On the Way')">\ud83d\ude97 START JOURNEY</button>`;
  } else if (e.status === "On the Way") {
    actions += `<button class="btn btn-arrived" onclick="updateStatus(${eid},'Arrived')">\ud83d\udccd MARK ARRIVED</button>`;
  } else if (e.status === "Arrived") {
    actions += `<button class="btn btn-resolve" onclick="updateStatus(${eid},'Resolved')">\u2705 RESOLVE</button>`;
  } else if (e.status === "Resolved") {
    actions += `<span style="color:#9ca3af;font-size:13px">\u2705 Emergency resolved</span>`;
  }

  const eta = e.estimated_minutes
    ? `<div class="eta-mini"><div class="eta-mini-label">ETA</div><div class="eta-mini-val">~${e.estimated_minutes} min</div><div class="eta-mini-dist">${e.distance ? (e.distance*1000).toFixed(0)+"m away" : ""}</div></div>`
    : "";

  panel.innerHTML = `
    <div class="detail-header">
      <div class="detail-id">\ud83d\udea8 Emergency #${e.id}</div>
      <div class="detail-badges">
        <span class="badge badge-${p}">${e.priority||"LOW"}</span>
        <span class="badge badge-${stCls}">${e.status}</span>
      </div>
    </div>
    
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-top: 20px;">
      
      <!-- LEFT COLUMN -->
      <div>
        <div style="margin-bottom: 16px; background: rgba(255,255,255,0.03); padding: 16px; border-radius: 12px; border: 1px solid var(--border);">
          <div style="font-size: 13px; font-weight: 700; color: var(--accent2); margin-bottom: 12px; text-transform: uppercase;">👤 STUDENT</div>
          <div style="display:flex; flex-direction:column; gap:8px;">
            <div><span style="color:var(--text3); font-size: 12px;">Name:</span> <br><strong>${e.student_name||"-"}</strong></div>
            <div><span style="color:var(--text3); font-size: 12px;">Mobile:</span> <br><strong>${e.mobile_number||"-"}</strong></div>
            <div><span style="color:var(--text3); font-size: 12px;">Enrollment:</span> <br><strong>${e.enrollment_number||"-"}</strong></div>
          </div>
        </div>

        <div style="background: rgba(255,255,255,0.03); padding: 16px; border-radius: 12px; border: 1px solid var(--border);">
          <div style="font-size: 13px; font-weight: 700; color: var(--accent2); margin-bottom: 12px; text-transform: uppercase;">🚨 EMERGENCY</div>
          <div style="display:flex; flex-direction:column; gap:8px;">
            <div><span style="color:var(--text3); font-size: 12px;">Type:</span> <br><span class="badge badge-${getTypeCls(e.emergency_type)}">${e.emergency_type||"-"}</span></div>
            <div><span style="color:var(--text3); font-size: 12px;">Priority:</span> <br><strong>${e.priority||"-"}</strong></div>
            <div><span style="color:var(--text3); font-size: 12px;">Risk Score:</span> <br><strong>${e.risk_score!=null?e.risk_score+"/100":"-"}</strong></div>
            <div><span style="color:var(--text3); font-size: 12px;">AI Confidence:</span> <br><strong>${e.ai_confidence?parseFloat(e.ai_confidence).toFixed(1)+"%":"-"}</strong></div>
            ${e.description ? `<div style="margin-top:8px;"><span style="color:var(--text3); font-size: 12px;">Full Description:</span> <div style="white-space:pre-wrap; max-height:150px; overflow-y:auto; padding: 8px; background:var(--card); border-radius:8px; border: 1px solid var(--border); font-size:13px;">${e.description}</div></div>` : ""}
            ${e.recommendation ? `<div style="margin-top:8px;"><span style="color:var(--text3); font-size: 12px;">AI Recommendation:</span> <div style="white-space:pre-wrap; max-height:150px; overflow-y:auto; padding: 8px; background:rgba(249,115,22,0.1); border-radius:8px; border: 1px solid rgba(249,115,22,0.2); font-size:13px; color:#fdba74;">${e.recommendation}</div></div>` : ""}
          </div>
        </div>
      </div>

      <!-- RIGHT COLUMN -->
      <div>
        <div style="margin-bottom: 16px; background:rgba(59,130,246,0.05); padding:16px; border:1px solid rgba(59,130,246,0.2); border-radius:12px;">
          <div style="font-size: 13px; font-weight: 700; color: #3b82f6; margin-bottom: 12px; text-transform: uppercase;">📍 LOCATION</div>
          <div style="font-size:16px; font-weight:700; color:#fff; margin-bottom:8px;">${e.location||"-"}</div>
          <div style="display:flex; flex-direction:column; gap:6px; font-size:13px; color:#9ca3af;">
            ${e.incident_lat && e.incident_lon ? `<div>Lat: ${parseFloat(e.incident_lat).toFixed(6)}<br>Lon: ${parseFloat(e.incident_lon).toFixed(6)}</div>` : ''}
            ${e.location_accuracy ? `<div>Accuracy: ±${Math.round(e.location_accuracy)}m</div>` : ''}
            <div>Reported At: ${fmtTime(e.time)}</div>
          </div>
        </div>

        <div style="background: rgba(255,255,255,0.03); padding: 16px; border-radius: 12px; border: 1px solid var(--border);">
          <div style="font-size: 13px; font-weight: 700; color: var(--accent2); margin-bottom: 12px; text-transform: uppercase;">👮 RESPONSE</div>
          <div style="display:flex; flex-direction:column; gap:8px;">
            <div><span style="color:var(--text3); font-size: 12px;">Responder:</span> <br><strong>${e.responder||"-"}</strong></div>
            <div><span style="color:var(--text3); font-size: 12px;">Distance:</span> <br><strong>${e.distance ? (e.distance).toFixed(2)+" km" : "-"}</strong></div>
            <div><span style="color:var(--text3); font-size: 12px;">ETA:</span> <br><strong>${e.estimated_minutes ? "~"+e.estimated_minutes+" min" : "-"}</strong></div>
            <div><span style="color:var(--text3); font-size: 12px;">Status:</span> <br><span class="badge badge-${stCls}">${e.status}</span></div>
          </div>
        </div>
      </div>
      
    </div>

    <div style="margin-top: 24px;">
      <div style="font-size: 13px; font-weight: 700; color: var(--text2); margin-bottom: 12px; text-transform: uppercase;">STATUS TIMELINE</div>
      <div class="status-flow">${statusFlow}</div>
    </div>
    
    <div class="detail-actions" style="margin-top:20px; border-top: 1px solid var(--border); padding-top: 16px;">${actions}</div>
  `;

  // Update map
  updateSecMap(e);
}

function updateStatus(eid, status) {
  fetch(`/api/emergency/${eid}/status`, {
    method: "POST", headers: {"Content-Type":"application/json"},
    body: JSON.stringify({ status })
  })
  .then(r => r.json())
  .then(d => {
    if (d.success) {
      showToast("\u2705 Updated", "Emergency #" + eid + " \u2192 " + status, "success");
      loadEmergencies();
      setTimeout(() => selectEmergency(eid), 400);
    }
  })
  .catch(() => showToast("\u274c Failed", "Could not update status.", "critical"));
}

// MAP
function initMap() {
  const el = document.getElementById("sec-map");
  if (!el) return;
  secMap = L.map("sec-map").setView([25.033, 74.6359], 16);
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", { attribution: "\u00a9 OpenStreetMap" }).addTo(secMap);

  fetch("/api/locations").then(r => r.json()).then(d => {
    d.locations.forEach(loc => {
      L.circleMarker([loc.lat, loc.lon], { radius:5, fillColor:"#6b7a99", color:"#fff", weight:1, fillOpacity:0.6 })
        .addTo(secMap).bindTooltip(loc.name, {direction:"top"});
    });
  });

  fetch("/api/responders").then(r => r.json()).then(d => {
    const cols = {"Medical Team":"#3b82f6","Fire Response Team":"#ef4444","Security Team":"#f97316"};
    d.responders.forEach(resp => {
      L.circleMarker([resp.lat, resp.lon], { radius:9, fillColor:cols[resp.name]||"#fff", color:"#fff", weight:2, fillOpacity:1 })
        .addTo(secMap).bindPopup(`<b>\ud83d\ude91 ${resp.name}</b>`).bindTooltip(resp.name);
    });
  });
}

let emgMapMarker = null;
let emgRouteLayer = null;

function updateSecMap(e) {
  if (!secMap) return;
  if (emgMapMarker) { secMap.removeLayer(emgMapMarker); emgMapMarker = null; }
  if (emgRouteLayer) { secMap.removeLayer(emgRouteLayer); emgRouteLayer = null; }

  fetch("/api/locations").then(r => r.json()).then(d => {
    const loc = d.locations.find(l => l.name === e.location);
    if (!loc) return;

    const pColors = {"CRITICAL":"#ef4444","HIGH":"#f97316","MEDIUM":"#eab308","LOW":"#22c55e"};
    const col = pColors[e.priority] || "#ef4444";

    emgMapMarker = L.circleMarker([loc.lat, loc.lon], { radius:14, fillColor:col, color:"#fff", weight:3, fillOpacity:0.9 })
      .addTo(secMap).bindPopup(`<b>\ud83d\udea8 Emergency #${e.id}</b><br>${e.emergency_type} - ${e.priority}`);

    secMap.setView([loc.lat, loc.lon], 17);

    // Route
    fetch("/api/responders").then(r => r.json()).then(rd => {
      const resp = rd.responders.find(r => r.name === e.responder);
      if (!resp) return;
      fetch(`/api/route?from_lat=${resp.lat}&from_lon=${resp.lon}&to_lat=${loc.lat}&to_lon=${loc.lon}`)
        .then(r => r.json()).then(rd2 => {
          if (rd2.code === "Ok" && rd2.routes) {
            const pts = rd2.routes[0].geometry.coordinates.map(c => [c[1],c[0]]);
            emgRouteLayer = L.polyline(pts, { color:col, weight:4, opacity:0.8 }).addTo(secMap);
          } else {
            emgRouteLayer = L.polyline([[resp.lat,resp.lon],[loc.lat,loc.lon]], { color:col, weight:3, dashArray:"8,6" }).addTo(secMap);
          }
        }).catch(() => {
          emgRouteLayer = L.polyline([[resp.lat,resp.lon],[loc.lat,loc.lon]], { color:col, weight:3, dashArray:"8,6" }).addTo(secMap);
        });
    });
  });
}

// ANALYTICS
function loadAnalytics() {
  fetch("/api/analytics").then(r => r.json()).then(renderAnalytics).catch(() => {});
}

function renderAnalytics(data) {
  const avgD = data.avg_dispatch_min != null ? data.avg_dispatch_min.toFixed(1) + " min" : "-";
  const avgA = data.avg_arrival_min  != null ? data.avg_arrival_min.toFixed(1)  + " min" : "-";
  const avgR = data.avg_resolution_min != null ? data.avg_resolution_min.toFixed(1) + " min" : "-";
  setText("a-dispatch", avgD);
  setText("a-arrival",  avgA);
  setText("a-resolve",  avgR);

  renderChart("chart-types", "doughnut", data.by_type, ["#3b82f6","#ef4444","#f97316","#22c55e","#a855f7"]);
  renderChart("chart-priority", "doughnut", data.by_priority, ["#ef4444","#f97316","#eab308","#22c55e"]);
  renderChart("chart-status", "bar", data.by_status, ["#fde047","#93c5fd","#fdba74","#86efac","#9ca3af"]);
  renderChart("chart-locations", "bar", data.by_location, ["#3b82f6"]);
}

function renderChart(id, type, dataObj, colors) {
  const canvas = document.getElementById(id);
  if (!canvas) return;

  const labels = Object.keys(dataObj);
  const values = Object.values(dataObj);

  if (charts[id]) { charts[id].destroy(); }

  charts[id] = new Chart(canvas, {
    type,
    data: {
      labels,
      datasets: [{
        data: values,
        backgroundColor: type === "bar"
          ? (colors[0] || "#3b82f6")
          : colors.slice(0, labels.length),
        borderColor: "transparent",
        borderRadius: type === "bar" ? 6 : 0
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: { display: type === "doughnut", position:"right", labels: { color:"#9aa5be", font:{size:11} } }
      },
      scales: type === "bar" ? {
        x: { ticks:{color:"#9aa5be",font:{size:10}}, grid:{color:"rgba(255,255,255,0.05)"} },
        y: { ticks:{color:"#9aa5be"}, grid:{color:"rgba(255,255,255,0.05)"}, beginAtZero:true }
      } : {}
    }
  });
}

// NOTIFICATIONS
function addNotification(data) {
  notifCount++;
  notifications.unshift(data);
  if (notifications.length > 20) notifications.pop();

  const badge = document.getElementById("notif-badge");
  if (badge) { badge.textContent = notifCount; badge.classList.remove("hidden"); }
  renderNotifList();
}

function renderNotifList() {
  const list = document.getElementById("notif-list");
  if (!list) return;
  list.innerHTML = notifications.slice(0, 10).map(n => {
    const cls = n.priority === "CRITICAL" ? " critical" : "";
    return `
      <div class="notif-item${cls}" onclick="selectEmergency(${n.id});toggleNotifPanel()">
        <div class="notif-item-top">
          <div class="notif-item-title">\ud83d\udea8 ${n.emergency_type}</div>
          <div class="notif-item-time">${fmtTimeAgo(n.reported_time)}</div>
        </div>
        <div class="notif-item-desc">${n.location} \u2022 ${n.priority} \u2022 ${n.student_name}</div>
      </div>`;
  }).join("");
}

function toggleNotifPanel() {
  const panel = document.getElementById("notif-panel");
  if (panel) panel.classList.toggle("hidden");
}

function clearNotifications() {
  notifCount = 0; notifications = [];
  const badge = document.getElementById("notif-badge");
  if (badge) badge.classList.add("hidden");
  renderNotifList();
}

function requestNotifPermission() {
  if ("Notification" in window && Notification.permission === "default") {
    Notification.requestPermission();
  }
}

function sendBrowserNotif(title, body) {
  if ("Notification" in window && Notification.permission === "granted") {
    new Notification(title, { body, icon: "/static/shield.png" });
  }
}

// UTILITIES
function getTypeCls(type) {
  if (!type) return "medium";
  const t = type.toLowerCase();
  if (t.includes("medical")) return "medical";
  if (t.includes("fire")) return "fire";
  if (t.includes("security")) return "security";
  if (t.includes("accident")) return "accident";
  return "medium";
}

function showToast(title, msg, type) {
  const cont = document.getElementById("toast-container");
  if (!cont) return;
  const icons = { critical:"\ud83d\udea8", success:"\u2705", info:"\u2139\ufe0f" };
  const t = document.createElement("div");
  t.className = "toast toast-" + type;
  t.innerHTML = `<div class="toast-icon">${icons[type]||"\ud83d\udd14"}</div><div class="toast-content"><div class="toast-title">${title}</div><div class="toast-msg">${msg}</div></div>`;
  cont.appendChild(t);
  setTimeout(() => { t.classList.add("fade-out"); setTimeout(() => t.remove(), 300); }, 5000);
}

function fmtTime(s) {
  if (!s) return "-";
  try { return new Date(s).toLocaleTimeString("en-IN",{hour:"2-digit",minute:"2-digit",second:"2-digit"}); }
  catch { return s; }
}

function fmtTimeAgo(s) {
  if (!s) return "";
  try {
    const diff = Math.floor((Date.now() - new Date(s).getTime()) / 1000);
    if (diff < 60) return diff + "s ago";
    if (diff < 3600) return Math.floor(diff/60) + "m ago";
    if (diff < 86400) return Math.floor(diff/3600) + "h ago";
    return new Date(s).toLocaleDateString("en-IN");
  } catch { return s; }
}
