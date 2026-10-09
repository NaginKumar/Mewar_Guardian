'use client';

import React, { useState } from 'react';
import { ShieldAlert, Navigation, Phone, CheckCircle, AlertTriangle, Radio, Sparkles, UserCheck, ShieldCheck, Flame, Cpu, Siren } from 'lucide-react';
import CampusMap from './CampusMap';

export default function SecurityDashboard({ activeAlert, onDispatch, status, responderLoc, studentLoc, distanceMeters, etaSeconds, speedKmH, groqAnalysis }) {
  const [selectedResponder, setSelectedResponder] = useState('QRT Patrol #04 (Officer Vikram)');

  const responders = [
    { name: 'QRT Patrol #04 (Officer Vikram)', vehicle: 'Security SUV', status: 'AVAILABLE', distance: '380m' },
    { name: 'Campus Guard Unit 2 (Officer Sunita)', vehicle: 'Patrol Bike', status: 'AVAILABLE', distance: '550m' },
    { name: 'Medical First Response (Dr. Amit)', vehicle: 'Ambulance', status: 'STANDBY', distance: '700m' }
  ];

  return (
    <div className="space-y-6">
      {/* Top Emergency Status Header */}
      <div className={`glass-panel p-6 rounded-3xl border transition-all ${activeAlert ? 'glass-panel-alert animate-siren-flash' : 'border-slate-800'}`}>
        <div className="flex flex-col md:flex-row items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <div className={`w-14 h-14 rounded-2xl flex items-center justify-center text-white ${activeAlert ? 'bg-red-600 animate-bounce shadow-2xl' : 'bg-slate-800 text-slate-400'}`}>
              <Siren className="w-8 h-8" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className={`px-2.5 py-0.5 rounded-full text-xs font-black tracking-wider uppercase ${activeAlert ? 'bg-red-500 text-white animate-pulse' : 'bg-slate-800 text-slate-400'}`}>
                  {activeAlert ? '🚨 CRITICAL SOS ALERT RECEIVED' : 'SYSTEM STANDBY — NO ACTIVE EMERGENCY'}
                </span>
                {groqAnalysis?.severity && (
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-extrabold bg-amber-500/20 text-amber-300 border border-amber-500/40">
                    Groq AI: {groqAnalysis.severity} ({groqAnalysis.threat_score}/100)
                  </span>
                )}
              </div>
              <h2 className="text-xl font-black text-white mt-1">
                {activeAlert ? `Emergency Report from ${activeAlert.studentName}` : 'Central Security Command & Dispatch Portal'}
              </h2>
            </div>
          </div>

          {/* Quick Dispatch CTA for Security Officer */}
          {activeAlert && status === 'idle' && (
            <button
              onClick={() => onDispatch(selectedResponder)}
              className="px-6 py-3.5 rounded-2xl bg-gradient-to-r from-red-600 via-rose-600 to-amber-500 hover:scale-105 text-white font-extrabold text-sm shadow-2xl flex items-center gap-2 transition-all cursor-pointer border border-red-400/40 animate-pulse shrink-0"
            >
              <Navigation className="w-5 h-5 fill-current" />
              DISPATCH SECURITY TEAM NOW ("Nikal Gaya")
            </button>
          )}

          {status !== 'idle' && (
            <div className="flex items-center gap-3 bg-emerald-950/60 border border-emerald-500/50 px-4 py-2.5 rounded-2xl text-xs font-bold text-emerald-300">
              <CheckCircle className="w-4 h-4 text-emerald-400" />
              <span>Team En Route to Student Location ({distanceMeters}m remaining)</span>
            </div>
          )}
        </div>
      </div>

      {/* Main Command Dashboard Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Active SOS Alert & Groq AI Analysis */}
        <div className="lg:col-span-5 space-y-6">
          {/* Active Incident Details Card */}
          {activeAlert ? (
            <div className="glass-panel p-6 rounded-3xl border border-red-500/40 space-y-4">
              <div className="flex items-center justify-between border-b border-slate-800 pb-3">
                <span className="text-xs font-mono font-bold text-red-400 flex items-center gap-1.5">
                  <ShieldAlert className="w-4 h-4" />
                  INCIDENT REF: {activeAlert.id}
                </span>
                <span className="text-xs font-mono text-slate-400">{activeAlert.timestamp}</span>
              </div>

              <div className="space-y-3">
                <div className="grid grid-cols-2 gap-3 text-xs">
                  <div className="bg-slate-900/80 p-3 rounded-2xl border border-slate-800">
                    <span className="text-slate-400 block text-[10px] uppercase font-bold">Student Name</span>
                    <span className="text-white font-extrabold text-sm">{activeAlert.studentName}</span>
                  </div>
                  <div className="bg-slate-900/80 p-3 rounded-2xl border border-slate-800">
                    <span className="text-slate-400 block text-[10px] uppercase font-bold">Student Contact</span>
                    <a href={`tel:${activeAlert.studentPhone}`} className="text-cyan-400 font-extrabold text-sm flex items-center gap-1 hover:underline">
                      <Phone className="w-3.5 h-3.5" />
                      {activeAlert.studentPhone}
                    </a>
                  </div>
                </div>

                <div className="bg-slate-900/80 p-3 rounded-2xl border border-slate-800 text-xs">
                  <span className="text-slate-400 block text-[10px] uppercase font-bold">Category & Location</span>
                  <div className="text-red-400 font-bold text-sm mt-0.5">{activeAlert.category}</div>
                  <div className="text-slate-200 mt-1 flex items-center gap-1">
                    <Radio className="w-3.5 h-3.5 text-blue-400" />
                    {activeAlert.location}
                  </div>
                </div>

                <div className="bg-slate-900/80 p-3 rounded-2xl border border-slate-800 text-xs">
                  <span className="text-slate-400 block text-[10px] uppercase font-bold">Problem Description</span>
                  <p className="text-slate-300 mt-1 leading-relaxed">{activeAlert.description}</p>
                </div>
              </div>

              {/* Select Responder Fleet Unit */}
              <div className="space-y-2 pt-2 border-t border-slate-800">
                <label className="block text-xs font-bold text-slate-300 uppercase tracking-wider">
                  Assign Quick Response Unit (QRT)
                </label>
                <select
                  value={selectedResponder}
                  onChange={(e) => setSelectedResponder(e.target.value)}
                  className="w-full bg-slate-900 border border-slate-700 rounded-xl p-2.5 text-xs text-slate-200 focus:outline-none focus:border-blue-500"
                >
                  {responders.map((r, i) => (
                    <option key={i} value={r.name}>
                      {r.name} ({r.vehicle} - {r.distance} away)
                    </option>
                  ))}
                </select>
              </div>

              {status === 'idle' ? (
                <button
                  onClick={() => onDispatch(selectedResponder)}
                  className="w-full py-3.5 px-4 rounded-xl bg-gradient-to-r from-red-600 via-rose-600 to-amber-500 hover:from-red-500 hover:to-rose-500 text-white font-black text-sm shadow-xl flex items-center justify-center gap-2 transition-all cursor-pointer border border-red-400/40"
                >
                  <Navigation className="w-4 h-4 fill-current" />
                  DISPATCH SECURITY & SEND LIVE TRACKING TO STUDENT
                </button>
              ) : (
                <div className="p-3 bg-emerald-950/40 border border-emerald-500/40 rounded-2xl text-xs text-emerald-300 flex items-center justify-between">
                  <span className="font-bold flex items-center gap-1.5">
                    <CheckCircle className="w-4 h-4 text-emerald-400" />
                    QRT Dispatched & Broadcast Active
                  </span>
                  <span className="font-mono">{Math.floor(etaSeconds / 60)}m {etaSeconds % 60}s ETA</span>
                </div>
              )}
            </div>
          ) : (
            <div className="glass-panel p-8 rounded-3xl text-center space-y-3 border border-slate-800">
              <ShieldCheck className="w-12 h-12 text-slate-600 mx-auto" />
              <h3 className="text-base font-bold text-slate-300">All Campus Sectors Clear</h3>
              <p className="text-xs text-slate-500">
                Waiting for incoming emergency signals. Any student SOS will trigger an instant acoustic siren and display incident location here.
              </p>
            </div>
          )}

          {/* Groq AI Threat Analysis & Safety Protocol */}
          {groqAnalysis && (
            <div className="glass-panel p-5 rounded-3xl border border-indigo-500/30 space-y-3 bg-gradient-to-br from-slate-950 via-indigo-950/20 to-slate-950">
              <div className="flex items-center justify-between border-b border-slate-800 pb-2.5">
                <div className="flex items-center gap-2">
                  <Sparkles className="w-4 h-4 text-indigo-400 animate-spin" />
                  <span className="text-xs font-extrabold text-indigo-300 uppercase tracking-wider">
                    Groq AI Threat Assessment Engine
                  </span>
                </div>
                <span className="text-[10px] font-mono text-slate-500">llama-3.3-70b</span>
              </div>

              <div className="space-y-2 text-xs">
                <p className="text-slate-300 leading-relaxed italic bg-slate-900/60 p-3 rounded-xl border border-slate-800">
                  "{groqAnalysis.summary}"
                </p>

                <div>
                  <span className="text-slate-400 font-bold block mb-1">Recommended QRT Protocol:</span>
                  <div className="p-2.5 rounded-xl bg-indigo-950/40 border border-indigo-500/30 text-indigo-200 font-medium">
                    {groqAnalysis.security_action}
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Right Column: Live Campus Dispatch Radar & Fleet Telemetry */}
        <div className="lg:col-span-7 space-y-6">
          <div className="space-y-2">
            <div className="flex items-center justify-between px-1">
              <h3 className="text-sm font-bold text-slate-200 flex items-center gap-2">
                <Radio className="w-4 h-4 text-emerald-400" />
                Live Command Campus Map & Fleet Positioning
              </h3>
              <span className="text-xs text-slate-400 font-mono">
                {status !== 'idle' ? `En Route - Speed: ${speedKmH} km/h` : 'Campus Grid Active'}
              </span>
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

          {/* Response Fleet Status Cards */}
          <div className="glass-panel p-5 rounded-3xl border border-slate-800 space-y-3">
            <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider flex items-center gap-2">
              <UserCheck className="w-4 h-4 text-blue-400" />
              On-Duty Quick Response Teams (QRT)
            </h4>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
              {responders.map((r, i) => (
                <div key={i} className="p-3 rounded-2xl bg-slate-900/80 border border-slate-800 space-y-1">
                  <div className="font-bold text-slate-200 truncate">{r.name}</div>
                  <div className="text-[11px] text-slate-400">{r.vehicle}</div>
                  <div className="flex items-center justify-between pt-1 text-[10px]">
                    <span className="text-emerald-400 font-bold">{r.status}</span>
                    <span className="text-slate-500 font-mono">{r.distance} away</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
