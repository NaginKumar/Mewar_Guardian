'use client';

import React, { useState, useEffect, useRef } from 'react';
import { Shield, User, Radio, Sparkles } from 'lucide-react';
import StudentPanel from './components/StudentPanel';
import SecurityDashboard from './components/SecurityDashboard';
import ChatAssistant from './components/ChatAssistant';
import AudioSiren from './components/AudioSiren';

export default function Home({ initialTab = 'student' }) {
  const [activeTab, setActiveTab] = useState(initialTab); // 'student' | 'security' | 'chat'
  const [activeAlert, setActiveAlert] = useState(null);
  const [messages, setMessages] = useState([]);
  const [status, setStatus] = useState('idle'); // 'idle' | 'dispatched' | 'en_route' | 'arrived'
  const [sirenSound, setSirenSound] = useState(false);

  // Map Coordinates Simulation (Percentage on campus grid 0-100)
  const [studentLoc, setStudentLoc] = useState({ x: 28, y: 35 });
  const [responderLoc, setResponderLoc] = useState({ x: 15, y: 85 });
  const [distanceMeters, setDistanceMeters] = useState(480);
  const [etaSeconds, setEtaSeconds] = useState(135);
  const [speedKmH, setSpeedKmH] = useState(0);
  const [groqAnalysis, setGroqAnalysis] = useState(null);

  const animationIntervalRef = useRef(null);

  // Sync state between open tabs (BroadcastChannel / LocalStorage)
  useEffect(() => {
    const handleStorage = (e) => {
      if (e.key === 'rakshak_emergency_event' && e.newValue) {
        try {
          const payload = JSON.parse(e.newValue);
          if (payload.type === 'NEW_SOS') {
            setActiveAlert(payload.alert);
            setSirenSound(true);
            setGroqAnalysis(payload.groqAnalysis || null);
          } else if (payload.type === 'DISPATCH') {
            startResponderMovement(payload.responderName);
          }
        } catch (err) {}
      }
    };
    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, []);

  // Trigger New Student SOS Alert
  const handleSendSOS = async (alertData) => {
    setActiveAlert(alertData);
    setStatus('idle');
    setSirenSound(true);
    setResponderLoc({ x: 15, y: 85 });
    setDistanceMeters(520);
    setEtaSeconds(145);
    setSpeedKmH(0);

    const newMsg = {
      sender: 'SYSTEM BROADCAST',
      text: `🚨 SOS Alert [${alertData.id}] registered from ${alertData.location}. Security Command Hub notified.`,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      type: 'sos'
    };
    setMessages([newMsg]);

    // Analyze with Groq AI in background
    try {
      const res = await fetch('/api/groq', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          category: alertData.category,
          location: alertData.location,
          description: alertData.description
        })
      });
      const data = await res.json();
      if (data.success && data.data) {
        setGroqAnalysis(data.data);
      }
    } catch (e) {}

    // Broadcast across browser tabs
    localStorage.setItem(
      'rakshak_emergency_event',
      JSON.stringify({ type: 'NEW_SOS', alert: alertData, timestamp: Date.now() })
    );
  };

  // Dispatch Responder Team ("jese vi nikle to student ke pass msg pahuche")
  const handleDispatch = (responderName) => {
    setStatus('en_route');
    setSirenSound(false);

    // Automated Dispatch Notification Message to Student
    const dispatchMsg = {
      sender: 'CHIEF SECURITY OFFICER',
      text: `⚡ Quick Response Unit [${responderName}] DISPATCHED ("Nikal Gaya"). Patrol vehicle is rushing to your exact position at ${activeAlert?.location || 'your location'}. Stay calm & keep phone visible.`,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      type: 'dispatch'
    };

    setMessages((prev) => [dispatchMsg, ...prev]);

    // Start Live GPS Movement Simulation
    startResponderMovement(responderName);

    localStorage.setItem(
      'rakshak_emergency_event',
      JSON.stringify({ type: 'DISPATCH', responderName, timestamp: Date.now() })
    );
  };

  // Live Responder GPS Movement Animation along Campus Coordinates
  const startResponderMovement = (responderName) => {
    if (animationIntervalRef.current) clearInterval(animationIntervalRef.current);

    let curDist = 480;
    let curEta = 120;
    let rx = 15;
    let ry = 85;
    const targetX = studentLoc.x;
    const targetY = studentLoc.y;

    animationIntervalRef.current = setInterval(() => {
      rx += (targetX - rx) * 0.12;
      ry += (targetY - ry) * 0.12;

      curDist = Math.max(0, Math.round(curDist - Math.random() * 35 - 15));
      curEta = Math.max(0, Math.round(curDist / 4.2));
      const currentSpeed = curDist > 0 ? Math.floor(22 + Math.random() * 8) : 0;

      setResponderLoc({ x: rx, y: ry });
      setDistanceMeters(curDist);
      setEtaSeconds(curEta);
      setSpeedKmH(currentSpeed);

      if (curDist <= 180 && curDist > 120) {
        setMessages((prev) => {
          if (!prev.some((m) => m.text.includes('180m'))) {
            return [
              {
                sender: 'QRT PATROL #04',
                text: `📍 Patrol Unit is within 180 meters! Sirens & strobe beacons active near ${activeAlert?.location || 'your location'}.`,
                time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                type: 'update'
              },
              ...prev
            ];
          }
          return prev;
        });
      }

      if (curDist <= 10) {
        clearInterval(animationIntervalRef.current);
        setStatus('arrived');
        setDistanceMeters(0);
        setEtaSeconds(0);
        setSpeedKmH(0);

        setMessages((prev) => [
          {
            sender: 'SECURITY HEADQUARTERS',
            text: `✅ OFFICERS ARRIVED ON SITE! Security team has reached ${activeAlert?.location || 'your location'}. Student safety secured.`,
            time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
            type: 'arrived'
          },
          ...prev
        ]);
      }
    }, 1000);
  };

  return (
    <div className="min-h-screen flex flex-col bg-[#070a12] text-slate-100 selection:bg-red-500 selection:text-white">
      <AudioSiren active={sirenSound} />

      {/* Top Header Navbar */}
      <header className="sticky top-0 z-50 glass-panel border-b border-slate-800/80 px-4 lg:px-8 py-3.5">
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-red-600 via-rose-600 to-amber-500 flex items-center justify-center text-white shadow-xl">
              <Shield className="w-6 h-6 fill-current" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className="text-xl font-black tracking-tight text-white">RAKSHAK AI</h1>
                <span className="text-[10px] font-extrabold px-2 py-0.5 rounded-md bg-red-500/20 text-red-400 border border-red-500/40 uppercase">
                  Live Unified Link
                </span>
              </div>
              <p className="text-xs text-slate-400">Campus Emergency SOS & Security Tracking System</p>
            </div>
          </div>

          {/* Role Switcher Tabs inside the Single Link */}
          <div className="flex items-center gap-1.5 bg-slate-900/90 p-1.5 rounded-2xl border border-slate-800">
            <button
              onClick={() => setActiveTab('student')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer ${
                activeTab === 'student'
                  ? 'bg-blue-600 text-white shadow-lg'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
              }`}
            >
              <User className="w-3.5 h-3.5" />
              Student Portal
            </button>

            <button
              onClick={() => setActiveTab('security')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 relative cursor-pointer ${
                activeTab === 'security'
                  ? 'bg-red-600 text-white shadow-lg'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
              }`}
            >
              <Radio className="w-3.5 h-3.5" />
              Security Control Hub
              {activeAlert && status === 'idle' && (
                <span className="w-2.5 h-2.5 rounded-full bg-red-500 animate-ping absolute top-1 right-1" />
              )}
            </button>

            <button
              onClick={() => setActiveTab('chat')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 cursor-pointer ${
                activeTab === 'chat'
                  ? 'bg-indigo-600 text-white shadow-lg'
                  : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
              }`}
            >
              <Sparkles className="w-3.5 h-3.5" />
              Groq AI Chatbot
            </button>
          </div>
        </div>
      </header>

      {/* Main Panel View */}
      <main className="flex-1 max-w-7xl w-full mx-auto p-4 sm:p-6 lg:p-8 space-y-6">
        {activeTab === 'student' && (
          <StudentPanel
            activeAlert={activeAlert}
            onSendSOS={handleSendSOS}
            messages={messages}
            responderLoc={responderLoc}
            studentLoc={studentLoc}
            distanceMeters={distanceMeters}
            etaSeconds={etaSeconds}
            status={status}
            speedKmH={speedKmH}
          />
        )}

        {activeTab === 'security' && (
          <SecurityDashboard
            activeAlert={activeAlert}
            onDispatch={handleDispatch}
            status={status}
            responderLoc={responderLoc}
            studentLoc={studentLoc}
            distanceMeters={distanceMeters}
            etaSeconds={etaSeconds}
            speedKmH={speedKmH}
            groqAnalysis={groqAnalysis}
          />
        )}

        {activeTab === 'chat' && (
          <ChatAssistant location={activeAlert?.location || 'Campus Main Grounds'} />
        )}
      </main>

      <footer className="glass-panel border-t border-slate-800/80 p-4 text-center text-xs text-slate-500">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-2">
          <div>© 2026 Rakshak AI Safety Network — Empowering Campus Security & Student Protection</div>
          <div className="flex items-center gap-4 text-[11px] text-slate-400">
            <span>Powered by Groq LLM & Next.js</span>
            <span>•</span>
            <span className="text-emerald-400 font-semibold">Security Hotline: +91-98765-43210</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
