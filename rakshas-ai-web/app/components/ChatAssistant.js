'use client';

import React, { useState, useRef, useEffect } from 'react';
import { Sparkles, Send, Bot, User, ShieldCheck, RefreshCw, MessageSquare } from 'lucide-react';

export default function ChatAssistant({ location }) {
  const [messages, setMessages] = useState([
    {
      sender: 'bot',
      text: `Namaste! Main Rakshak AI Assistant hoon. Aap mujhse campus safety, emergency guidance, ya koi bhi sawal pooch sakte hain. Main har sawaal ka alag aur conversational jawab dunga!`
    }
  ]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const chatEndRef = useRef(null);

  const quickPrompts = [
    'Raat me hostel wapas aane ki safety tips?',
    'Emergency SOS button kaise kaam karta hai?',
    'Campus me nearest security post kahan hai?',
    'Main akela mehsoos kar raha hoon, kya karun?'
  ];

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, loading]);

  const handleSend = async (textToSend) => {
    const userMsg = (textToSend || input).trim();
    if (!userMsg || loading) return;

    setInput('');
    const newMessages = [...messages, { sender: 'user', text: userMsg }];
    setMessages(newMessages);
    setLoading(true);

    try {
      const res = await fetch('/api/groq', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          mode: 'chat',
          prompt: userMsg,
          history: messages,
          location
        })
      });

      const data = await res.json();
      const botReply = data.response || 'Stay safe. Main aapki madad ke liye hamesha ready hoon.';

      setMessages((prev) => [...prev, { sender: 'bot', text: botReply }]);
    } catch (err) {
      setMessages((prev) => [
        ...prev,
        { sender: 'bot', text: 'Khatre ke waqt turant Red SOS Button dabayein ya Security HQ ko call karein.' }
      ]);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="glass-panel p-6 rounded-3xl border border-indigo-500/30 max-w-4xl mx-auto space-y-4 shadow-2xl bg-gradient-to-b from-slate-950 via-slate-900 to-slate-950">
      {/* Header */}
      <div className="flex items-center justify-between border-b border-slate-800 pb-4">
        <div className="flex items-center gap-3">
          <div className="w-11 h-11 rounded-2xl bg-gradient-to-tr from-indigo-600 to-purple-500 border border-indigo-400/40 flex items-center justify-center text-white shadow-lg">
            <Sparkles className="w-6 h-6 animate-pulse" />
          </div>
          <div>
            <h3 className="text-base font-extrabold text-white flex items-center gap-2">
              Rakshak Groq AI Smart Chatbot
              <span className="text-[10px] font-mono font-bold bg-indigo-500/20 text-indigo-300 border border-indigo-500/40 px-2 py-0.5 rounded-full">
                llama-3.3-70b
              </span>
            </h3>
            <p className="text-xs text-slate-400">Conversational AI — Ask anything in Hindi, Hinglish, or English</p>
          </div>
        </div>

        <button
          onClick={() =>
            setMessages([
              {
                sender: 'bot',
                text: 'Chat history reset ho gayi hai. Naye sawal ke saath shuru karein!'
              }
            ])
          }
          className="p-2 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-800 text-slate-400 hover:text-slate-200 text-xs flex items-center gap-1.5 transition-colors cursor-pointer"
        >
          <RefreshCw className="w-3.5 h-3.5" /> Reset Chat
        </button>
      </div>

      {/* Quick Suggestion Chips */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 text-xs">
        <span className="text-slate-500 text-[11px] font-bold shrink-0 flex items-center gap-1">
          <MessageSquare className="w-3 h-3 text-indigo-400" /> Quick Ask:
        </span>
        {quickPrompts.map((promptText, i) => (
          <button
            key={i}
            onClick={() => handleSend(promptText)}
            className="px-3 py-1.5 rounded-xl bg-slate-900/90 border border-slate-800 hover:border-indigo-500/50 text-slate-300 hover:text-white text-xs shrink-0 transition-colors cursor-pointer"
          >
            {promptText}
          </button>
        ))}
      </div>

      {/* Messages Stream Container */}
      <div className="space-y-4 h-[380px] overflow-y-auto pr-2">
        {messages.map((msg, i) => (
          <div
            key={i}
            className={`flex items-start gap-3 text-xs ${msg.sender === 'user' ? 'flex-row-reverse' : ''}`}
          >
            <div
              className={`w-9 h-9 rounded-2xl flex items-center justify-center shrink-0 font-bold shadow-md ${
                msg.sender === 'user'
                  ? 'bg-blue-600 text-white'
                  : 'bg-gradient-to-tr from-indigo-600 to-purple-600 text-white'
              }`}
            >
              {msg.sender === 'user' ? <User className="w-4 h-4" /> : <Bot className="w-4 h-4" />}
            </div>
            <div
              className={`p-4 rounded-2xl max-w-[82%] leading-relaxed text-xs shadow-md whitespace-pre-wrap ${
                msg.sender === 'user'
                  ? 'bg-blue-600 text-white rounded-tr-none font-medium'
                  : 'bg-slate-900/95 border border-slate-800 text-slate-200 rounded-tl-none font-normal'
              }`}
            >
              {msg.text}
            </div>
          </div>
        ))}

        {loading && (
          <div className="flex items-center gap-2 text-xs text-indigo-400 italic font-mono pl-12 py-2">
            <Sparkles className="w-4 h-4 animate-spin text-indigo-400" />
            Rakshak AI is typing response...
          </div>
        )}

        <div ref={chatEndRef} />
      </div>

      {/* Input Box */}
      <form
        onSubmit={(e) => {
          e.preventDefault();
          handleSend();
        }}
        className="flex gap-2 pt-2 border-t border-slate-800"
      >
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Kuchh bhi poochhein (e.g., Raat ko akale hostel kaise jaun, safety tips)..."
          className="flex-1 bg-slate-900 border border-slate-700 rounded-xl px-4 py-3 text-xs text-slate-100 placeholder-slate-500 focus:outline-none focus:border-indigo-500 transition-colors"
        />
        <button
          type="submit"
          disabled={loading || !input.trim()}
          className="px-6 py-3 rounded-xl bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-500 hover:to-purple-500 disabled:opacity-50 text-white font-extrabold text-xs flex items-center gap-2 transition-all shadow-lg cursor-pointer"
        >
          <Send className="w-4 h-4" /> Send
        </button>
      </form>
    </div>
  );
}
