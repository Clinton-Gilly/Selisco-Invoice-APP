import React from 'react';
import Link from 'next/link';
import { query } from '@/lib/db';
import {
  FileText,
  Truck,
  ShieldCheck,
  Download,
  Activity,
  CheckCircle2,
  Server,
  Database,
  ArrowUpRight,
  TrendingUp,
  Clock,
  Sparkles,
  ExternalLink,
} from 'lucide-react';

export const dynamic = 'force-dynamic';

export default async function DashboardPage() {
  let stats = {
    totalRevenue: 0,
    grossBilled: 0,
    totalInvoices: 0,
    paidInvoices: 0,
    pendingInvoices: 0,
    totalDeliveries: 0,
    deliveredCount: 0,
    deliveryRate: 100,
    dbConnected: false,
  };

  try {
    const invRes = await query(`
      SELECT 
        COALESCE(SUM(CASE WHEN status = 'PAID' THEN total_amount ELSE 0 END), 0)::numeric as total_revenue,
        COALESCE(SUM(total_amount), 0)::numeric as gross_billed,
        COUNT(*)::int as total_invoices,
        COUNT(CASE WHEN status = 'PAID' THEN 1 END)::int as paid_invoices,
        COUNT(CASE WHEN status IN ('ISSUED', 'OVERDUE') THEN 1 END)::int as pending_invoices
      FROM invoices;
    `);

    const delRes = await query(`
      SELECT 
        COUNT(*)::int as total_deliveries,
        COUNT(CASE WHEN status = 'DELIVERED' THEN 1 END)::int as delivered_count
      FROM delivery_notes;
    `);

    const inv = invRes.rows[0] || {};
    const del = delRes.rows[0] || {};

    const totalDel = parseInt(del.total_deliveries || '0', 10);
    const delivered = parseInt(del.delivered_count || '0', 10);

    stats = {
      totalRevenue: parseFloat(inv.total_revenue || '0'),
      grossBilled: parseFloat(inv.gross_billed || '0'),
      totalInvoices: parseInt(inv.total_invoices || '0', 10),
      paidInvoices: parseInt(inv.paid_invoices || '0', 10),
      pendingInvoices: parseInt(inv.pending_invoices || '0', 10),
      totalDeliveries: totalDel,
      deliveredCount: delivered,
      deliveryRate: totalDel > 0 ? Math.round((delivered / totalDel) * 100) : 100,
      dbConnected: true,
    };
  } catch (err) {
    console.warn('Dashboard DB query fallback:', err);
  }

  const formatCurrency = (val: number) => {
    return new Intl.NumberFormat('en-KE', {
      style: 'currency',
      currency: 'KES',
      maximumFractionDigits: 0,
    }).format(val);
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 font-sans selection:bg-indigo-500 selection:text-white">
      {/* Top Banner / Navigation */}
      <header className="border-b border-slate-800/80 bg-slate-900/50 backdrop-blur-xl sticky top-0 z-50">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 to-indigo-400 flex items-center justify-center shadow-lg shadow-indigo-500/20">
              <ShieldCheck className="w-6 h-6 text-white" />
            </div>
            <div>
              <span className="font-black text-lg tracking-tight text-white flex items-center gap-2">
                SELISCO
                <span className="text-[10px] uppercase font-bold tracking-widest px-2 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30">
                  Cloud Dashboard
                </span>
              </span>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="hidden sm:inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-medium">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              {stats.dbConnected ? 'Neon DB Online' : 'Cloud API Active'}
            </div>
            <Link
              href="/download"
              className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold shadow-md shadow-indigo-600/20 transition-all active:scale-95"
            >
              <Download className="w-3.5 h-3.5" />
              Download Mobile App
            </Link>
          </div>
        </div>
      </header>

      {/* Main Container */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 space-y-10">
        {/* Welcome Section */}
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-6 pb-2 border-b border-slate-800/60">
          <div>
            <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-indigo-500/10 border border-indigo-500/30 rounded-full text-indigo-300 text-xs font-semibold mb-3">
              <Sparkles className="w-3.5 h-3.5 text-indigo-400" />
              Enterprise Invoice &amp; Delivery Management
            </div>
            <h1 className="text-3xl sm:text-4xl font-black text-white tracking-tight">
              Selisco Business Operations Portal
            </h1>
            <p className="mt-1 text-slate-400 text-sm max-w-2xl">
              Cloud orchestration engine powering mobile invoices, cryptographic QR verification, delivery tracking, and intelligent analytics.
            </p>
          </div>
          <div className="flex items-center gap-3">
            <Link
              href="/api/version"
              target="_blank"
              className="inline-flex items-center gap-2 px-3.5 py-2 rounded-xl bg-slate-800/90 hover:bg-slate-700/80 border border-slate-700 text-slate-300 text-xs font-medium transition"
            >
              <Activity className="w-4 h-4 text-indigo-400" />
              API Health &amp; Version
              <ArrowUpRight className="w-3.5 h-3.5 text-slate-500" />
            </Link>
          </div>
        </div>

        {/* Live Metrics Grid */}
        <section>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-base font-bold text-white flex items-center gap-2">
              <TrendingUp className="w-4 h-4 text-indigo-400" />
              Real-Time Financial &amp; Operational Metrics
            </h2>
            <span className="text-xs text-slate-500">Live from Neon Database</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {/* Card 1: Revenue */}
            <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 hover:border-slate-700 transition">
              <div className="flex items-center justify-between text-slate-400 text-xs font-medium mb-3">
                <span>Total Collected Revenue</span>
                <span className="p-2 rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                  <TrendingUp className="w-4 h-4" />
                </span>
              </div>
              <div className="text-2xl font-black text-white tracking-tight">
                {formatCurrency(stats.totalRevenue)}
              </div>
              <p className="text-xs text-emerald-400 mt-2 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" />
                {stats.paidInvoices} settled invoices
              </p>
            </div>

            {/* Card 2: Gross Billed */}
            <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 hover:border-slate-700 transition">
              <div className="flex items-center justify-between text-slate-400 text-xs font-medium mb-3">
                <span>Gross Invoiced Total</span>
                <span className="p-2 rounded-lg bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                  <FileText className="w-4 h-4" />
                </span>
              </div>
              <div className="text-2xl font-black text-white tracking-tight">
                {formatCurrency(stats.grossBilled)}
              </div>
              <p className="text-xs text-slate-400 mt-2 flex items-center gap-1">
                <Clock className="w-3.5 h-3.5 text-amber-400" />
                {stats.pendingInvoices} invoices awaiting payment
              </p>
            </div>

            {/* Card 3: Total Invoices */}
            <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 hover:border-slate-700 transition">
              <div className="flex items-center justify-between text-slate-400 text-xs font-medium mb-3">
                <span>Total Registered Invoices</span>
                <span className="p-2 rounded-lg bg-blue-500/10 text-blue-400 border border-blue-500/20">
                  <FileText className="w-4 h-4" />
                </span>
              </div>
              <div className="text-2xl font-black text-white tracking-tight">
                {stats.totalInvoices}
              </div>
              <div className="w-full bg-slate-800 rounded-full h-1.5 mt-3 overflow-hidden">
                <div
                  className="bg-indigo-500 h-1.5 rounded-full"
                  style={{
                    width: stats.totalInvoices > 0 ? `${(stats.paidInvoices / stats.totalInvoices) * 100}%` : '0%',
                  }}
                />
              </div>
            </div>

            {/* Card 4: Deliveries */}
            <div className="bg-slate-900/80 border border-slate-800 rounded-2xl p-5 hover:border-slate-700 transition">
              <div className="flex items-center justify-between text-slate-400 text-xs font-medium mb-3">
                <span>Delivery Fulfillment</span>
                <span className="p-2 rounded-lg bg-amber-500/10 text-amber-400 border border-amber-500/20">
                  <Truck className="w-4 h-4" />
                </span>
              </div>
              <div className="text-2xl font-black text-white tracking-tight">
                {stats.deliveryRate}%
              </div>
              <p className="text-xs text-slate-400 mt-2">
                {stats.deliveredCount} of {stats.totalDeliveries} orders delivered
              </p>
            </div>
          </div>
        </section>

        {/* Quick Access & Cloud Services Grid */}
        <section className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Card 1: Document Verification Portal */}
          <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 flex flex-col justify-between hover:border-indigo-500/40 transition group">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 mb-5 group-hover:scale-105 transition-transform">
                <ShieldCheck className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Cryptographic Document Verification</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Scan QR codes printed on invoices or delivery notes to verify document authenticity, cryptographic hash, and tamper-proof history.
              </p>
            </div>
            <div className="mt-6 pt-4 border-t border-slate-800">
              <div className="text-xs text-slate-500 mb-2">Endpoint format:</div>
              <code className="text-[11px] block bg-slate-950 p-2 rounded-lg border border-slate-800 text-indigo-300 font-mono break-all">
                /verify/&#123;invoice_id&#125;?token=&#123;token&#125;
              </code>
            </div>
          </div>

          {/* Card 2: Mobile App Hub */}
          <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 flex flex-col justify-between hover:border-indigo-500/40 transition group">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 mb-5 group-hover:scale-105 transition-transform">
                <Download className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Selisco Mobile Client (v1.1.0)</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Android client featuring biometric lock, offline storage, AI Copilot, 1-tap WhatsApp sharing, and automatic OTA cloud updates.
              </p>
            </div>
            <div className="mt-6 pt-4 border-t border-slate-800 flex gap-2">
              <Link
                href="/download"
                className="flex-1 py-2.5 px-3 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-semibold text-center transition active:scale-95"
              >
                Download Page
              </Link>
              <a
                href="/selisco.apk"
                download="selisco.apk"
                className="py-2.5 px-3 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-xl text-xs font-semibold text-center transition"
              >
                Direct APK
              </a>
            </div>
          </div>

          {/* Card 3: Cloud Infrastructure */}
          <div className="bg-slate-900/90 border border-slate-800 rounded-3xl p-6 flex flex-col justify-between hover:border-indigo-500/40 transition group">
            <div>
              <div className="w-12 h-12 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 flex items-center justify-center text-indigo-400 mb-5 group-hover:scale-105 transition-transform">
                <Server className="w-6 h-6" />
              </div>
              <h3 className="text-lg font-bold text-white mb-2">Cloud Infrastructure &amp; APIs</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Powered by Next.js 14 serverless edge execution, Neon Serverless PostgreSQL with connection pooling, and multi-provider AI adapters.
              </p>
            </div>
            <div className="mt-6 pt-4 border-t border-slate-800 space-y-2">
              <div className="flex items-center justify-between text-xs text-slate-400">
                <span className="flex items-center gap-1.5">
                  <Database className="w-3.5 h-3.5 text-indigo-400" />
                  Database
                </span>
                <span className="text-emerald-400 font-mono text-[11px]">Neon Postgres</span>
              </div>
              <div className="flex items-center justify-between text-xs text-slate-400">
                <span className="flex items-center gap-1.5">
                  <Activity className="w-3.5 h-3.5 text-indigo-400" />
                  API Endpoints
                </span>
                <span className="text-slate-300 font-mono text-[11px]">RESTful JSON</span>
              </div>
            </div>
          </div>
        </section>

        {/* API Reference & Cloud Push Ready status */}
        <section className="bg-slate-900/60 border border-slate-800/80 rounded-2xl p-6">
          <h3 className="text-sm font-bold text-white mb-4 flex items-center gap-2">
            <Server className="w-4 h-4 text-indigo-400" />
            Active Cloud Microservices &amp; REST Routes
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 text-xs">
            <div className="bg-slate-950 p-3 rounded-xl border border-slate-800/80 flex items-center justify-between">
              <span className="font-mono text-indigo-300">GET /api/invoices</span>
              <span className="text-[10px] uppercase font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">Active</span>
            </div>
            <div className="bg-slate-950 p-3 rounded-xl border border-slate-800/80 flex items-center justify-between">
              <span className="font-mono text-indigo-300">GET /api/delivery-notes</span>
              <span className="text-[10px] uppercase font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">Active</span>
            </div>
            <div className="bg-slate-950 p-3 rounded-xl border border-slate-800/80 flex items-center justify-between">
              <span className="font-mono text-indigo-300">GET /api/analytics</span>
              <span className="text-[10px] uppercase font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">Active</span>
            </div>
            <div className="bg-slate-950 p-3 rounded-xl border border-slate-800/80 flex items-center justify-between">
              <span className="font-mono text-indigo-300">POST /api/copilot/chat</span>
              <span className="text-[10px] uppercase font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">Active</span>
            </div>
            <div className="bg-slate-950 p-3 rounded-xl border border-slate-800/80 flex items-center justify-between">
              <span className="font-mono text-indigo-300">GET /api/version</span>
              <span className="text-[10px] uppercase font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">Active</span>
            </div>
            <div className="bg-slate-950 p-3 rounded-xl border border-slate-800/80 flex items-center justify-between">
              <span className="font-mono text-indigo-300">GET /verify/:id</span>
              <span className="text-[10px] uppercase font-bold text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded">Active</span>
            </div>
          </div>
        </section>
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-800/80 mt-16 py-8 text-center text-xs text-slate-500">
        <p>&copy; {new Date().getFullYear()} Selisco Technologies. All rights reserved.</p>
        <p className="mt-1">Cloud Deployment Ready • Vercel • Docker • Neon PostgreSQL</p>
      </footer>
    </div>
  );
}
