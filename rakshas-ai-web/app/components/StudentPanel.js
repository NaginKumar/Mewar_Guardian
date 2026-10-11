'use client';

import React, { useState } from 'react';
import { ShieldAlert, Send, PhoneCall, CheckCircle2, Clock, MapPin, Bell, MessageSquare, AlertTriangle, UserCheck, ShieldCheck } from 'lucide-react';
import CampusMap from './CampusMap';

export default function StudentPanel({ activeAlert, onSendSOS, messages, responderLoc, studentLoc, distanceMeters, etaSeconds, status, speedKmH }) {
  const [category, setCategory] = useState('Physical Threat / Stalking');
  const [location, setLocation] = useState('Hostel Block C (Near Entrance)');
  const [description, setDescription] = useState('');
  const [studentName, setStudentName] = useState('Aarav Sharma (DEMO ONLY)');
  const [studentPhone, setStudentPhone] = useState('9000000001');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const categories = [
    { id: 'Physical Threat / Stalking', label: 'Physical Threat / Stalking', icon: ShieldAlert, color: 'text-red-400', bg: 'border-red-500/30 bg-red-950/20' },
    { id: 'Medical Emergency', label: 'Medical Emergency', icon: AlertTriangle, color: 'text-amber-400', bg: 'border-amber-500/30 bg-amber-950/20' },
    { id: 'Harassment', label: 'Harassment / Suspicious Activity', icon: Bell, color: 'text-purple-400', bg: 'border-purple-500/30 bg-purple-950/20' },
    { id: 'Fire / Hazard', label: 'Fire / Safety Hazard', icon: AlertTriangle, color: 'text-orange-400', bg: 'border-orange-500/30 bg-orange-950/20' }
  ];

  const locations = [
    'Hostel Block C (Near Entrance)',
    'Central Library (2nd Floor)',
    'Science Complex Quad',
    'Admin Building Ground Floor',
    'Cafeteria Plaza',
    'Sports Ground East Stand',
    'Main Gate / Security Kiosk'
  ];

  const handleInstantSOS = () => {
    onSendSOS({
      id: 'SOS-' + Date.now().toString().slice(-4),
      studentName,
      studentPhone,
      category,
      location,
      description: description || 'INSTANT EMERGENCY SOS TRIGGERED BY STUDENT PANIC BUTTON.',
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
      status: 'pending'
    });
  };

  const handleSubmitForm = (e) => {
    e.preventDefault();
    setIsSubmitting(true);
    setTimeout(() => {
      onSendSOS({
        id: 'INC-' + Date.now().toString().slice(-4),
        studentName,
        studentPhone,
        category,
        location,
        description: description || `Reported ${category} at ${location}`,
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }),
        status: 'pending'
      });
      setIsSubmitting(false);
    }, 400);
  };

  return (
    <div className="space-y-6">
      {/* Quick SOS Panic Banner */}
      <div className="glass-panel p-6 rounded-3xl border border-red-500/40 relative overflow-hidden bg-gradient-to-r from-red-950/40 via-slate-900 to-slate-950">
        <div className="absolute -right-10 -bottom-10 w-48 h-48 bg-red-600/10 rounded-full blur-3xl pointer-events-none" />
        <div className="flex flex-col md:flex-row items-center justify-between gap-6 relative z-10">
          <div className="space-y-2 text-center md:text-left">
            <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-red-500/20 border border-red-500/40 text-red-300 text-xs font-bold tracking-wider uppercase">
              <span className="w-2 h-2 rounded-full bg-red-500 animate-ping" />
              1-Tap Emergency Broadcast
            </div>
            <h2 className="text-2xl font-extrabold text-white tracking-tight">Need Immediate Emergency Help?</h2>
            <p className="text-sm text-slate-300 max-w-xl">
              Tap the red SOS button to broadcast your GPS position directly to the Central Security Command & QRT Patrol Teams.
            </p>
          </div>

          <button
            onClick={handleInstantSOS}
            className="group relative flex flex-col items-center justify-center w-28 h-28 rounded-full bg-gradient-to-tr from-red-700 via-red-600 to-rose-500 text-white font-extrabold shadow-2xl hover:scale-105 transition-all duration-300 active:scale-95 border-4 border-red-400/40 animate-emergency-pulse shrink-0 cursor-pointer"
          >
            <ShieldAlert className="w-10 h-10 group-hover:rotate-12 transition-transform" />
            <span className="text-xs font-black tracking-wider uppercase mt-0.5">SEND SOS</span>
          </button>
        </div>
      </div>

      {/* Main Grid: Incident Form & Live Responder Tracking Feed */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Problem Reporting Form */}
        <div className="lg:col-span-5 space-y-6">
          <div className="glass-panel p-6 rounded-3xl space-y-5">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div>
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  <MessageSquare className="w-5 h-5 text-blue-400" />
                  Report Emergency / Problem
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">Send structured alert with details to campus security</p>
              </div>
            </div>

            <form onSubmit={handleSubmitForm} className="space-y-4">
              {/* Category Selector */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-2">
                  Select Incident Category
                </label>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                  {categories.map((cat) => {
                    const Icon = cat.icon;
                    const selected = category === cat.id;
                    return (
                      <button
                        type="button"
                        key={cat.id}
                        onClick={() => setCategory(cat.id)}
                        className={`flex items-center gap-2.5 p-3 rounded-xl text-left border text-xs font-semibold transition-all ${
                          selected
                            ? 'bg-blue-600/20 border-blue-500 text-white shadow-lg'
                            : 'bg-slate-900/60 border-slate-800 text-slate-400 hover:border-slate-700'
                        }`}
                      >
                        <Icon className={`w-4 h-4 shrink-0 ${cat.color}`} />
                        <span className="truncate">{cat.label}</span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Location Picker */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
                  Campus Location
                </label>
                <div className="relative">
                  <MapPin className="w-4 h-4 text-slate-400 absolute left-3 top-3.5" />
                  <select
                    value={location}
                    onChange={(e) => setLocation(e.target.value)}
                    className="w-full bg-slate-900/90 border border-slate-700 rounded-xl pl-9 pr-4 py-2.5 text-sm text-slate-200 focus:outline-none focus:border-blue-500 transition-colors"
                  >
                    {locations.map((loc, i) => (
                      <option key={i} value={loc} className="bg-slate-900 text-slate-200">
                        {loc}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {/* Student Contact Info */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-semibold text-slate-400 uppercase mb-1">Your Name</label>
                  <input
                    type="text"
                    value={studentName}
                    onChange={(e) => setStudentName(e.target.value)}
                    className="w-full bg-slate-900/90 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-blue-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-semibold text-slate-400 uppercase mb-1">Phone Number</label>
                  <input
                    type="text"
                    value={studentPhone}
                    onChange={(e) => setStudentPhone(e.target.value)}
                    className="w-full bg-slate-900/90 border border-slate-800 rounded-xl px-3 py-2 text-xs text-slate-200 focus:outline-none focus:border-blue-500"
                  />
                </div>
              </div>

              {/* Problem Description */}
              <div>
                <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
                  Describe Problem / Situation
                </label>
                <textarea
                  rows="3"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Explain what happened, any threat nearby, or required assistance..."
                  className="w-full bg-slate-900/90 border border-slate-700 rounded-xl p-3 text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-blue-500 transition-colors resize-none"
                />
              </div>

              {/* Submit Button */}
              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full py-3 px-4 rounded-xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-500 hover:to-indigo-500 text-white font-bold text-sm shadow-xl flex items-center justify-center gap-2 transition-all cursor-pointer"
              >
                <Send className="w-4 h-4" />
                {isSubmitting ? 'Sending Alert...' : 'Submit Problem & Notify Security'}
              </button>
            </form>
          </div>

          {/* Quick Hotline Contacts Card */}
          <div className="glass-panel p-5 rounded-3xl border border-slate-800 space-y-3">
            <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
              <PhoneCall className="w-4 h-4 text-emerald-400" />
              Direct Emergency Helpline
            </h4>
            <div className="grid grid-cols-2 gap-2 text-xs">
              <a href="tel:+919876543210" className="flex items-center gap-2 p-2.5 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-emerald-500/50 transition-colors">
                <div className="w-7 h-7 rounded-lg bg-emerald-500/20 text-emerald-400 flex items-center justify-center shrink-0">
                  <PhoneCall className="w-3.5 h-3.5" />
                </div>
                <div>
                  <div className="font-semibold text-slate-200">Main HQ</div>
                  <div className="text-[11px] text-slate-400">+91-98765-43210</div>
                </div>
              </a>
              <a href="tel:112" className="flex items-center gap-2 p-2.5 rounded-xl bg-slate-900/80 border border-slate-800 hover:border-red-500/50 transition-colors">
                <div className="w-7 h-7 rounded-lg bg-red-500/20 text-red-400 flex items-center justify-center shrink-0">
                  <ShieldCheck className="w-3.5 h-3.5" />
                </div>
                <div>
                  <div className="font-semibold text-slate-200">National SOS</div>
                  <div className="text-[11px] text-slate-400">112</div>
                </div>
              </a>
            </div>
          </div>
        </div>

        {/* Right Column: Live Radar Tracking & Real-Time Security Dispatch Messages */}
        <div className="lg:col-span-7 space-y-6">
          {/* Real-time Campus Radar Map */}
          <div className="space-y-2">
            <div className="flex items-center justify-between px-1">
              <h3 className="text-sm font-bold text-slate-200 flex items-center gap-2">
                <MapPin className="w-4 h-4 text-red-400" />
                Live Responder Radar & GPS Tracking
              </h3>
              {status !== 'idle' && (
                <span className="text-xs text-slate-400 font-mono">
                  Distance: <strong className="text-white">{distanceMeters}m</strong> | Speed: <strong className="text-blue-400">{speedKmH} km/h</strong>
                </span>
              )}
            </div>

            <CampusMap
              studentLoc={studentLoc}
              responderLoc={responderLoc}
              status={status}
              distanceMeters={distanceMeters}
              etaSeconds={etaSeconds}
              speedKmH={speedKmH}
            />
          </div>

          {/* Real-time Arrival Timer Card ("pahuchne ka theek samay") */}
          {status !== 'idle' && (
            <div className={`glass-panel p-5 rounded-3xl border flex items-center justify-between ${status === 'arrived' ? 'glass-panel-success' : 'glass-panel-alert'}`}>
              <div className="flex items-center gap-4">
                <div className={`w-12 h-12 rounded-2xl flex items-center justify-center text-white font-bold ${status === 'arrived' ? 'bg-emerald-600' : 'bg-red-600 animate-pulse'}`}>
                  <Clock className="w-6 h-6" />
                </div>
                <div>
                  <div className="text-xs text-slate-300 font-medium">Estimated Arrival Time (Theek Samay)</div>
                  <div className="text-2xl font-black tracking-tight text-white font-mono">
                    {status === 'arrived' ? (
                      <span className="text-emerald-400 flex items-center gap-1.5">
                        <CheckCircle2 className="w-6 h-6 inline" /> OFFICER ARRIVED!
                      </span>
                    ) : (
                      `${Math.floor(etaSeconds / 60)} MIN ${etaSeconds % 60} SEC`
                    )}
                  </div>
                </div>
              </div>

              <div className="text-right">
                <div className="text-xs text-slate-400">Patrol Unit</div>
                <div className="text-sm font-bold text-cyan-300 flex items-center gap-1">
                  <UserCheck className="w-4 h-4 text-cyan-400" />
                  QRT Alpha Patrol #04
                </div>
              </div>
            </div>
          )}

          {/* Real-time Notifications / Messages Log ("Student ke pass msg pahuche") */}
          <div className="glass-panel p-5 rounded-3xl border border-slate-800 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-800 pb-3">
              <h4 className="text-sm font-bold text-white flex items-center gap-2">
                <Bell className="w-4 h-4 text-amber-400" />
                Live Responder Notifications & Updates
              </h4>
              <span className="text-xs text-slate-500 font-mono">{messages.length} Messages</span>
            </div>

            <div className="space-y-3 max-h-[220px] overflow-y-auto pr-1">
              {messages.length === 0 ? (
                <div className="text-center py-8 text-xs text-slate-500">
                  No active messages. When you submit a problem or hit SOS, live security updates will appear here instantly.
                </div>
              ) : (
                messages.map((msg, idx) => (
                  <div
                    key={idx}
                    className={`p-3.5 rounded-2xl text-xs border transition-all ${
                      msg.type === 'dispatch'
                        ? 'bg-amber-950/30 border-amber-500/40 text-amber-200'
                        : msg.type === 'arrived'
                        ? 'bg-emerald-950/40 border-emerald-500/40 text-emerald-200'
                        : 'bg-slate-900/80 border-slate-800 text-slate-300'
                    }`}
                  >
                    <div className="flex items-center justify-between font-bold mb-1">
                      <span className="flex items-center gap-1.5">
                        {msg.type === 'dispatch' && <span className="w-2 h-2 rounded-full bg-amber-400 animate-ping" />}
                        {msg.sender}
                      </span>
                      <span className="text-[10px] opacity-75 font-mono">{msg.time}</span>
                    </div>
                    <p className="leading-relaxed font-medium">{msg.text}</p>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
