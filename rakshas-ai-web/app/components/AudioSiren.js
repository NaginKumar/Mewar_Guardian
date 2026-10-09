'use client';

import React, { useEffect, useRef } from 'react';

export default function AudioSiren({ active }) {
  const audioCtxRef = useRef(null);

  useEffect(() => {
    if (!active) return;

    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;

      const ctx = new AudioCtx();
      audioCtxRef.current = ctx;

      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = 'sawtooth';
      gain.gain.setValueAtTime(0.15, ctx.currentTime);

      // Oscillate siren frequency between 600Hz and 1200Hz
      const now = ctx.currentTime;
      osc.frequency.setValueAtTime(600, now);
      osc.frequency.linearRampToValueAtTime(1200, now + 0.4);
      osc.frequency.linearRampToValueAtTime(600, now + 0.8);
      osc.frequency.linearRampToValueAtTime(1200, now + 1.2);
      osc.frequency.linearRampToValueAtTime(600, now + 1.6);

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start();
      osc.stop(now + 1.8);
    } catch (e) {
      // Audio autoplay policy fallback
    }

    return () => {
      if (audioCtxRef.current) {
        audioCtxRef.current.close().catch(() => {});
      }
    };
  }, [active]);

  return null;
}
