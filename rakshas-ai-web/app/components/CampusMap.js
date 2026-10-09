'use client';

import React from 'react';
import { MapPin, ShieldAlert, Navigation, Compass, Radio } from 'lucide-react';

export default function CampusMap({ studentLoc, responderLoc, status, distanceMeters, etaSeconds, speedKmH }) {
  // Campus landmarks mapping relative to canvas percentage coordinates (0-100%)
  const landmarks = [
    { name: 'Hostel Block C', x: 22, y: 30, type: 'building' },
    { name: 'Central Library', x: 70, y: 25, type: 'building' },
    { name: 'Science Quad', x: 80, y: 70, type: 'building' },
    { name: 'Admin Block', x: 45, y: 50, type: 'building' },
    { name: 'Main Gate', x: 15, y: 85, type: 'gate' },
    { name: 'Cafeteria', x: 50, y: 20, type: 'amenity' },
    { name: 'Sports Ground', x: 82, y: 40, type: 'sports' }
  ];

  // Calculate coordinates on canvas percentage
  const sPos = studentLoc || { x: 28, y: 35 };
  const rPos = responderLoc || { x: 15, y: 85 };

  // Calculate angle for orientation vector
  const deltaX = sPos.x - rPos.x;
  const deltaY = sPos.y - rPos.y;
  const angleRad = Math.atan2(deltaY, deltaX);
  const angleDeg = (angleRad * 180) / Math.PI;

  return (
    <div className="relative w-full h-[420px] rounded-2xl overflow-hidden glass-panel border border-slate-800 bg-slate-950/90 shadow-2xl flex flex-col">
      {/* Map Header Overlay */}
      <div className="absolute top-3 left-3 right-3 z-20 flex items-center justify-between pointer-events-none">
        <div className="flex items-center gap-2 bg-slate-900/90 backdrop-blur-md px-3 py-1.5 rounded-xl border border-slate-700/60 shadow-lg pointer-events-auto">
          <div className="relative flex h-3 w-3">
            <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${status === 'dispatched' ? 'bg-amber-400' : status === 'en_route' ? 'bg-emerald-400' : 'bg-red-400'}`}></span>
            <span className={`relative inline-flex rounded-full h-3 w-3 ${status === 'dispatched' ? 'bg-amber-500' : status === 'en_route' ? 'bg-emerald-500' : 'bg-red-500'}`}></span>
          </div>
          <span className="text-xs font-semibold text-slate-200 tracking-wide uppercase">
            {status === 'arrived' ? 'Officer Arrived On Site' : status === 'en_route' ? 'Live Radar Tracking' : status === 'dispatched' ? 'Team Mobilized' : 'Campus Grid Standby'}
          </span>
        </div>

        {/* Live Telemetry Pill */}
        {(status === 'en_route' || status === 'dispatched') && (
          <div className="flex items-center gap-3 bg-slate-900/90 backdrop-blur-md px-3.5 py-1.5 rounded-xl border border-blue-500/40 shadow-lg text-xs font-mono text-blue-300 pointer-events-auto">
            <div className="flex items-center gap-1.5">
              <Navigation className="w-3.5 h-3.5 text-blue-400 animate-pulse" />
              <span>{distanceMeters}m remaining</span>
            </div>
            <span className="text-slate-600">|</span>
            <div className="flex items-center gap-1.5 text-emerald-400 font-bold">
              <span>ETA: {Math.floor(etaSeconds / 60)}m {etaSeconds % 60}s</span>
            </div>
          </div>
        )}
      </div>

      {/* SVG Canvas Map Grid */}
      <div className="relative w-full h-full bg-[#0a0f1d] overflow-hidden">
        <svg className="w-full h-full absolute inset-0 pointer-events-none" xmlns="http://www.w3.org/2000/svg">
          {/* Map Grid Pattern */}
          <defs>
            <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
              <path d="M 40 0 L 0 0 0 40" fill="none" stroke="rgba(255, 255, 255, 0.04)" strokeWidth="1" />
            </pattern>
            <linearGradient id="routeGradient" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#ef4444" stopOpacity="0.8" />
              <stop offset="50%" stopColor="#3b82f6" stopOpacity="0.9" />
              <stop offset="100%" stopColor="#10b981" stopOpacity="1" />
            </linearGradient>
          </defs>

          <rect width="100%" height="100%" fill="url(#grid)" />

          {/* Campus Road Networks */}
          <path d="M 15% 85% Q 30% 60% 45% 50% T 70% 25% T 82% 40%" fill="none" stroke="rgba(51, 65, 85, 0.5)" strokeWidth="14" strokeLinecap="round" />
          <path d="M 22% 30% L 45% 50% L 80% 70%" fill="none" stroke="rgba(51, 65, 85, 0.5)" strokeWidth="10" strokeLinecap="round" />

          {/* Live Dispatch Path line connecting Responder & Student */}
          {status !== 'idle' && (
            <>
              <line
                x1={`${rPos.x}%`}
                y1={`${rPos.y}%`}
                x2={`${sPos.x}%`}
                y2={`${sPos.y}%`}
                stroke="url(#routeGradient)"
                strokeWidth="4"
                strokeDasharray="8 6"
                className="animate-[dash_20s_linear_infinite]"
              />
              {/* Radar Sweep Effect centered at Student */}
              <circle
                cx={`${sPos.x}%`}
                cy={`${sPos.y}%`}
                r="70"
                fill="none"
                stroke="rgba(239, 68, 68, 0.2)"
                strokeWidth="1"
              />
              <circle
                cx={`${sPos.x}%`}
                cy={`${sPos.y}%`}
                r="120"
                fill="none"
                stroke="rgba(239, 68, 68, 0.1)"
                strokeWidth="1"
              />
            </>
          )}
        </svg>

        {/* Campus Buildings Overlay Pins */}
        {landmarks.map((lm, idx) => (
          <div
            key={idx}
            className="absolute transform -translate-x-1/2 -translate-y-1/2 flex flex-col items-center opacity-60 hover:opacity-100 transition-opacity"
            style={{ left: `${lm.x}%`, top: `${lm.y}%` }}
          >
            <div className="w-3 h-3 rounded-sm bg-slate-700 border border-slate-500/50 shadow-sm" />
            <span className="text-[10px] font-medium text-slate-400 mt-1 whitespace-nowrap bg-slate-950/80 px-1.5 py-0.5 rounded border border-slate-800">
              {lm.name}
            </span>
          </div>
        ))}

        {/* STUDENT PIN (SOS Source) */}
        <div
          className="absolute z-30 transform -translate-x-1/2 -translate-y-1/2 transition-all duration-300"
          style={{ left: `${sPos.x}%`, top: `${sPos.y}%` }}
        >
          <div className="relative flex flex-col items-center">
            <div className="relative flex items-center justify-center">
              <span className="animate-ping absolute inline-flex h-12 w-12 rounded-full bg-red-500 opacity-75"></span>
              <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-red-600 to-rose-500 border-2 border-white flex items-center justify-center shadow-2xl text-white">
                <ShieldAlert className="w-5 h-5 animate-bounce" />
              </div>
            </div>
            <div className="bg-red-950/90 text-red-200 border border-red-500/50 text-[11px] font-bold px-2 py-0.5 rounded-full mt-1.5 shadow-xl whitespace-nowrap">
              Student SOS Pin
            </div>
          </div>
        </div>

        {/* RESPONDER PIN (Security Team moving dynamically) */}
        {status !== 'idle' && (
          <div
            className="absolute z-40 transform -translate-x-1/2 -translate-y-1/2 transition-all duration-1000 ease-linear"
            style={{ left: `${rPos.x}%`, top: `${rPos.y}%` }}
          >
            <div className="relative flex flex-col items-center">
              <div className="relative flex items-center justify-center">
                <span className="animate-ping absolute inline-flex h-14 w-14 rounded-full bg-blue-500 opacity-60"></span>
                <div
                  className="w-11 h-11 rounded-full bg-gradient-to-tr from-blue-600 to-cyan-400 border-2 border-white flex items-center justify-center shadow-2xl text-white transform transition-transform duration-500"
                  style={{ transform: `rotate(${angleDeg + 90}deg)` }}
                >
                  <Navigation className="w-6 h-6 fill-current text-white" />
                </div>
              </div>
              <div className="bg-slate-900/95 text-cyan-300 border border-cyan-400/60 text-[11px] font-extrabold px-2.5 py-0.5 rounded-full mt-1.5 shadow-2xl flex items-center gap-1.5 whitespace-nowrap">
                <Radio className="w-3 h-3 text-cyan-400 animate-pulse" />
                <span>QRT Patrol #04 ({speedKmH} km/h)</span>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Map Footer Bar */}
      <div className="p-3 bg-slate-900/90 border-t border-slate-800 flex items-center justify-between text-xs text-slate-400">
        <div className="flex items-center gap-2">
          <Compass className="w-4 h-4 text-slate-500" />
          <span>Coordinates: 28.5432° N, 77.1923° E (Sector 4 Campus)</span>
        </div>
        <div className="flex items-center gap-3">
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-red-500"></span> Student</span>
          <span className="flex items-center gap-1"><span className="w-2 h-2 rounded-full bg-blue-500"></span> Security QRT</span>
        </div>
      </div>
    </div>
  );
}
