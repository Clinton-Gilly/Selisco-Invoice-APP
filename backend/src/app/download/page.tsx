import React from 'react';
import { Download, ShieldCheck, Smartphone, ArrowRight, CheckCircle } from 'lucide-react';

export default function DownloadPage() {
  return (
    <div className="min-h-screen bg-slate-900 text-white flex flex-col justify-center items-center px-4 py-12 font-sans selection:bg-indigo-500 selection:text-white">
      <div className="max-w-md w-full bg-slate-800/90 border border-slate-700/80 rounded-3xl p-8 shadow-2xl backdrop-blur-xl text-center">
        {/* Emblem */}
        <div className="w-20 h-20 bg-indigo-600/20 border border-indigo-500/40 rounded-2xl mx-auto flex items-center justify-center mb-6 shadow-inner">
          <Smartphone className="w-10 h-10 text-indigo-400 animate-pulse" />
        </div>

        {/* Title */}
        <h1 className="text-2xl font-black tracking-tight text-white mb-2">
          Selisco Mobile Client
        </h1>
        <p className="text-slate-400 text-sm mb-6">
          Invoice & Delivery Note Management with Enterprise Biometric Security & PDF Verification
        </p>

        {/* Big Download Button */}
        <a
          href="/selisco.apk"
          download="selisco.apk"
          className="inline-flex items-center justify-center gap-3 w-full py-4 px-6 bg-gradient-to-r from-indigo-600 to-indigo-500 hover:from-indigo-500 hover:to-indigo-400 text-white font-bold text-base rounded-2xl shadow-lg shadow-indigo-600/30 transition-all transform active:scale-95 mb-4"
        >
          <Download className="w-5 h-5" />
          Download & Install APK (Direct)
        </a>

        <p className="text-xs text-slate-500 mb-6">
          Direct fast download from Selisco Cloud • Android 8.0+
        </p>

        {/* Simple 3-step Instructions */}
        <div className="text-left bg-slate-900/60 rounded-xl p-4 border border-slate-700/50 space-y-2 text-xs text-slate-300">
          <div className="flex items-center gap-2 font-semibold text-indigo-400 mb-1">
            <CheckCircle className="w-4 h-4" /> Quick Install Steps:
          </div>
          <p>1. Tap the <strong className="text-white">Download</strong> button above.</p>
          <p>2. In your Chrome notifications, tap <strong className="text-white">Open</strong> or <strong className="text-white">Install</strong>.</p>
          <p>3. If prompted to allow installs from browser, tap <strong className="text-white">Settings → Allow</strong>.</p>
        </div>

        <div className="mt-6 flex items-center justify-center gap-2 text-xs text-slate-500">
          <ShieldCheck className="w-4 h-4 text-emerald-400" />
          Secured with Local Biometrics & Neon DB
        </div>
      </div>
    </div>
  );
}
