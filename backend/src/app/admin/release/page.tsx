'use client';

import React, { useEffect, useState } from 'react';
import { Rocket, ShieldAlert, CheckCircle2 } from 'lucide-react';

interface Release {
  version: string;
  releaseNotes: string;
  downloadUrl: string;
  minVersion: string;
  publishedAt?: string;
}

const TOKEN_KEY = 'selisco_release_admin_token';

export default function ReleaseAdminPage() {
  const [current, setCurrent] = useState<Release | null>(null);
  const [form, setForm] = useState<Release>({ version: '', releaseNotes: '', downloadUrl: '', minVersion: '1.0.0' });
  const [token, setToken] = useState('');
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(null);

  useEffect(() => {
    try {
      setToken(sessionStorage.getItem(TOKEN_KEY) || '');
    } catch {}
    fetch('/api/version', { cache: 'no-store' })
      .then((r) => r.json())
      .then((res) => {
        if (res.success) {
          setCurrent(res.data);
          setForm({
            version: res.data.version,
            releaseNotes: res.data.releaseNotes,
            downloadUrl: res.data.downloadUrl,
            minVersion: res.data.minVersion || '1.0.0',
          });
        }
      })
      .catch(() => setMessage({ ok: false, text: 'Could not load the current release.' }));
  }, []);

  async function publish(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setMessage(null);
    try {
      try {
        sessionStorage.setItem(TOKEN_KEY, token);
      } catch {}
      const res = await fetch('/api/version', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-admin-token': token },
        body: JSON.stringify(form),
      });
      const json = await res.json();
      if (!json.success) throw new Error(json.error || 'Failed to publish');
      setCurrent(json.data);
      setMessage({
        ok: true,
        text: `Published v${json.data.version}. Phones on an older version will see the update prompt next time they open the app.`,
      });
    } catch (err: any) {
      setMessage({ ok: false, text: err.message });
    } finally {
      setSaving(false);
    }
  }

  const input =
    'w-full rounded-xl bg-slate-950 border border-slate-700 px-3 py-2.5 text-sm text-white focus:outline-none focus:border-indigo-500';
  const forced = form.minVersion && form.version && form.minVersion === form.version;

  return (
    <div className="min-h-screen bg-slate-900 text-white px-4 py-10">
      <div className="max-w-xl mx-auto">
        <div className="flex items-center gap-3 mb-6">
          <div className="w-11 h-11 rounded-2xl bg-indigo-500/15 border border-indigo-500/30 flex items-center justify-center">
            <Rocket className="w-5 h-5 text-indigo-400" />
          </div>
          <div>
            <h1 className="text-xl font-black">Mobile App Release</h1>
            <p className="text-xs text-slate-400">Tell installed apps that a new version is available.</p>
          </div>
        </div>

        {current && (
          <div className="mb-6 rounded-2xl border border-slate-700 bg-slate-800/70 p-4 text-sm">
            <div className="text-slate-400 text-xs mb-1">Live now</div>
            <div className="font-bold text-lg">v{current.version}</div>
            <div className="text-xs text-slate-400 break-all">{current.downloadUrl}</div>
            <div className="text-xs text-slate-400 mt-1">Required minimum: v{current.minVersion}</div>
          </div>
        )}

        <form onSubmit={publish} className="space-y-4 rounded-2xl border border-slate-700 bg-slate-800/70 p-5">
          <div className="grid grid-cols-2 gap-3">
            <label className="block">
              <span className="text-xs text-slate-300">Latest version</span>
              <input
                className={input}
                value={form.version}
                onChange={(e) => setForm({ ...form, version: e.target.value })}
                placeholder="1.2.0"
                required
              />
            </label>
            <label className="block">
              <span className="text-xs text-slate-300">Minimum allowed version</span>
              <input
                className={input}
                value={form.minVersion}
                onChange={(e) => setForm({ ...form, minVersion: e.target.value })}
                placeholder="1.0.0"
                required
              />
            </label>
          </div>
          <p className="text-[11px] text-slate-400 -mt-2">
            Phones below the minimum cannot skip the update. Set it equal to the latest version to force everyone to update.
          </p>

          <label className="block">
            <span className="text-xs text-slate-300">APK download link (https)</span>
            <input
              className={input}
              value={form.downloadUrl}
              onChange={(e) => setForm({ ...form, downloadUrl: e.target.value })}
              placeholder="https://.../selisco.apk"
              required
            />
          </label>

          <label className="block">
            <span className="text-xs text-slate-300">What&apos;s new (shown in the update prompt)</span>
            <textarea
              className={`${input} min-h-[120px]`}
              value={form.releaseNotes}
              onChange={(e) => setForm({ ...form, releaseNotes: e.target.value })}
            />
          </label>

          <label className="block">
            <span className="text-xs text-slate-300">Admin token</span>
            <input
              className={input}
              type="password"
              value={token}
              onChange={(e) => setToken(e.target.value)}
              required
            />
          </label>

          {forced && (
            <div className="flex items-center gap-2 text-xs text-amber-300">
              <ShieldAlert className="w-4 h-4" /> Everyone will be required to update before using the app.
            </div>
          )}

          {message && (
            <div
              className={`flex items-start gap-2 text-xs rounded-xl p-3 ${
                message.ok ? 'bg-emerald-500/10 text-emerald-300' : 'bg-red-500/10 text-red-300'
              }`}
            >
              {message.ok && <CheckCircle2 className="w-4 h-4 shrink-0" />}
              {message.text}
            </div>
          )}

          <button
            type="submit"
            disabled={saving}
            className="w-full py-3 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 font-bold text-sm"
          >
            {saving ? 'Publishing…' : 'Publish release'}
          </button>
        </form>
      </div>
    </div>
  );
}
