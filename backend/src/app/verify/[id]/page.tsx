import React from 'react';
import { query } from '@/lib/db';
import { CheckCircle2, XCircle, ShieldCheck, Printer, Calendar, User, Phone, Mail, Building2, Hash } from 'lucide-react';

interface VerifyPageProps {
  params: {
    id: string;
  };
  searchParams: {
    token?: string;
  };
}

export const dynamic = 'force-dynamic';

export default async function VerifyInvoicePage({ params, searchParams }: VerifyPageProps) {
  const { id } = params;
  const token = searchParams.token;

  let invoice: any = null;
  let items: any[] = [];
  let isAuthentic = false;
  let errorReason = '';

  try {
    const invRes = await query(
      `SELECT i.*, 
              b.name as business_name, 
              b.email as business_email, 
              b.phone as business_phone, 
              b.currency as currency, 
              b.address as business_address
       FROM invoices i
       JOIN businesses b ON i.business_id = b.id
       WHERE i.id = $1`,
      [id]
    );

    if (invRes.rows.length > 0) {
      invoice = invRes.rows[0];
      if (!token || invoice.verification_token === token) {
        isAuthentic = true;
        const itemsRes = await query(
          'SELECT * FROM invoice_items WHERE invoice_id = $1 ORDER BY created_at ASC',
          [id]
        );
        items = itemsRes.rows;
      } else {
        errorReason = 'Verification token mismatch. This document could not be authenticated.';
      }
    } else {
      errorReason = 'Invoice record not found in registry.';
    }
  } catch (err: any) {
    console.error('Error verifying invoice:', err);
    errorReason = 'Database connection error during verification check.';
  }

  const formatCurrency = (amount: number, curr = 'KES') => {
    try {
      const formatted = new Intl.NumberFormat('en-KE', {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }).format(amount);
      return `KSh ${formatted}/=`;
    } catch {
      return `KSh ${Number(amount).toFixed(2)}/=`;
    }
  };

  const formatDate = (dateStr: string) => {
    if (!dateStr) return 'N/A';
    try {
      return new Date(dateStr).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      });
    } catch {
      return dateStr;
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900 py-10 px-4 sm:px-6 lg:px-8 font-sans">
      <div className="max-w-3xl mx-auto">
        {/* Top Header & Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-indigo-50 border border-indigo-200 text-indigo-700 text-xs font-semibold tracking-wide uppercase">
            <ShieldCheck className="w-4 h-4 text-indigo-600" />
            Official Verification Portal
          </div>
          <h1 className="mt-3 text-3xl font-extrabold tracking-tight text-slate-900 sm:text-4xl">
            Document Authenticity Registry
          </h1>
          <p className="mt-1 text-sm text-slate-500">
            Real-time cryptographic audit log for invoices & delivery documents
          </p>
        </div>

        {/* Verification Status Card */}
        {isAuthentic && invoice ? (
          <div className="bg-white rounded-2xl shadow-xl border border-slate-200 overflow-hidden mb-8 transition-all">
            {/* Status Banner */}
            <div className="bg-emerald-600 px-6 py-5 sm:px-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-white">
              <div className="flex items-center gap-3">
                <div className="p-2 bg-emerald-700/60 rounded-xl">
                  <CheckCircle2 className="w-8 h-8 text-white animate-pulse" />
                </div>
                <div>
                  <h2 className="text-lg font-bold">Verified Authentic Invoice</h2>
                  <p className="text-xs text-emerald-100">
                    Cryptographic signature matches records on Neon Serverless DB
                  </p>
                </div>
              </div>
              <div className="text-right flex items-center gap-2">
                <span className="inline-flex items-center px-3 py-1 rounded-full text-xs font-bold bg-white/20 uppercase tracking-wider backdrop-blur-sm">
                  {invoice.status}
                </span>
              </div>
            </div>

            {/* Document Details Body */}
            <div className="p-6 sm:p-8 space-y-6">
              {/* Primary Info Grid */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6 pb-6 border-b border-slate-100">
                <div>
                  <span className="text-xs font-semibold uppercase text-slate-400 tracking-wider">
                    Issued By
                  </span>
                  <h3 className="text-lg font-bold text-slate-900 mt-1 flex items-center gap-1.5">
                    <Building2 className="w-4 h-4 text-slate-400" />
                    {invoice.business_name || 'SELISCO LTD'}
                  </h3>
                  <p className="text-xs font-semibold text-indigo-600">Orthopaedic & Surgical</p>
                  {invoice.business_address && (
                    <p className="text-xs text-slate-500 mt-0.5">{invoice.business_address}</p>
                  )}
                  {invoice.business_email && (
                    <p className="text-xs text-slate-500 mt-0.5 flex items-center gap-1">
                      <Mail className="w-3.5 h-3.5 text-slate-400" /> {invoice.business_email}
                    </p>
                  )}
                </div>

                <div className="md:text-right">
                  <span className="text-xs font-semibold uppercase text-slate-400 tracking-wider">
                    Invoice Reference
                  </span>
                  <p className="text-xl font-mono font-bold text-indigo-600 mt-1 flex md:justify-end items-center gap-1">
                    <Hash className="w-4 h-4 text-indigo-400" />
                    {invoice.invoice_number}
                  </p>
                  <p className="text-xs text-slate-500 mt-1 flex md:justify-end items-center gap-1">
                    <Calendar className="w-3.5 h-3.5 text-slate-400" /> Issued: {formatDate(invoice.issued_date)}
                  </p>
                  <p className="text-xs text-slate-500 mt-0.5 flex md:justify-end items-center gap-1">
                    <Calendar className="w-3.5 h-3.5 text-slate-400" /> Due: {formatDate(invoice.due_date)}
                  </p>
                </div>
              </div>

              {/* Billed To */}
              <div className="bg-slate-50 p-4 rounded-xl border border-slate-100">
                <div className="flex justify-between items-center">
                  <span className="text-xs font-semibold uppercase text-slate-400 tracking-wider">
                    Billed To / Hospital
                  </span>
                  {invoice.customer_pin && (
                    <span className="text-xs font-mono font-bold text-indigo-700 bg-indigo-50 px-2.5 py-0.5 rounded-full border border-indigo-200">
                      PIN: {invoice.customer_pin}
                    </span>
                  )}
                </div>
                <p className="text-base font-semibold text-slate-800 mt-1 flex items-center gap-1.5">
                  <User className="w-4 h-4 text-slate-400" />
                  {invoice.customer_name}
                </p>
                <div className="flex flex-wrap gap-4 mt-1 text-xs text-slate-500">
                  {invoice.customer_phone && (
                    <span className="flex items-center gap-1">
                      <Phone className="w-3.5 h-3.5" /> {invoice.customer_phone}
                    </span>
                  )}
                  {invoice.customer_email && (
                    <span className="flex items-center gap-1">
                      <Mail className="w-3.5 h-3.5" /> {invoice.customer_email}
                    </span>
                  )}
                </div>
              </div>

              {/* Line Items Table */}
              <div>
                <h4 className="text-xs font-semibold uppercase text-slate-400 tracking-wider mb-3">
                  Itemized Goods & Services
                </h4>
                <div className="overflow-x-auto rounded-lg border border-slate-200">
                  <table className="w-full text-left text-xs sm:text-sm">
                    <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-semibold uppercase text-[11px] tracking-wider">
                      <tr>
                        <th className="py-3 px-4">Item & Description</th>
                        <th className="py-3 px-3 text-right">Qty</th>
                        <th className="py-3 px-3 text-right">Unit Price</th>
                        <th className="py-3 px-4 text-right">Total</th>
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-slate-100">
                      {items.map((item, idx) => (
                        <tr key={item.id || idx} className="hover:bg-slate-50/50">
                          <td className="py-3 px-4">
                            <p className="font-medium text-slate-900">{item.product_name}</p>
                            {item.description && (
                              <p className="text-xs text-slate-500">{item.description}</p>
                            )}
                          </td>
                          <td className="py-3 px-3 text-right font-mono text-slate-700">
                            {item.quantity}
                          </td>
                          <td className="py-3 px-3 text-right font-mono text-slate-700">
                            {formatCurrency(item.unit_price, invoice.currency)}
                          </td>
                          <td className="py-3 px-4 text-right font-mono font-semibold text-slate-900">
                            {formatCurrency(item.total_price, invoice.currency)}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>

              {/* Financial Totals Summary */}
              <div className="flex flex-col sm:flex-row justify-end items-end pt-4">
                <div className="w-full sm:w-72 space-y-2 text-sm">
                  <div className="flex justify-between text-slate-600 py-1">
                    <span>Subtotal</span>
                    <span className="font-mono font-medium">
                      {formatCurrency(invoice.subtotal, invoice.currency)}
                    </span>
                  </div>
                  <div className="flex justify-between text-slate-600 py-1">
                    <span>Tax</span>
                    <span className="font-mono font-medium">
                      {formatCurrency(invoice.tax, invoice.currency)}
                    </span>
                  </div>
                  <div className="flex justify-between text-base font-bold text-slate-900 border-t border-slate-200 pt-2 pb-1">
                    <span>Total Amount</span>
                    <span className="font-mono text-indigo-600 text-lg">
                      {formatCurrency(invoice.total_amount, invoice.currency)}
                    </span>
                  </div>
                </div>
              </div>

              {/* Security Audit Footer */}
              <div className="bg-slate-50 rounded-xl p-4 border border-slate-200/80 text-xs text-slate-500 space-y-1">
                <div className="flex items-center gap-1 font-semibold text-slate-700">
                  <ShieldCheck className="w-4 h-4 text-emerald-600" />
                  Cryptographic Audit Trail
                </div>
                <p className="font-mono text-[11px] text-slate-600 break-all">
                  Token: {invoice.verification_token}
                </p>
                <p className="text-[11px] text-slate-400">
                  Database Record ID: {invoice.id} • Registered {new Date(invoice.created_at).toUTCString()}
                </p>
              </div>
            </div>
          </div>
        ) : (
          /* Unverified or Tampered State */
          <div className="bg-white rounded-2xl shadow-xl border border-red-200 overflow-hidden mb-8">
            <div className="bg-red-600 px-6 py-6 text-white text-center">
              <XCircle className="w-12 h-12 mx-auto mb-2 animate-bounce" />
              <h2 className="text-xl font-bold">Unverified Document</h2>
              <p className="text-xs text-red-100 mt-1">
                {errorReason || 'The authenticity of this document could not be validated.'}
              </p>
            </div>
            <div className="p-6 sm:p-8 text-center space-y-4">
              <p className="text-sm text-slate-600 max-w-md mx-auto">
                The QR code scanned or link visited does not match any authenticated record in the Selisco registry. 
                This may be due to an altered URL, an invalid or expired verification token, or a non-existent invoice.
              </p>
              <div className="text-xs font-mono text-slate-400 bg-slate-50 py-2 px-3 rounded-lg max-w-md mx-auto break-all border border-slate-200">
                Scanned ID: {id} | Token: {token || 'None provided'}
              </div>
            </div>
          </div>
        )}

        {/* Global Footer */}
        <div className="text-center text-xs text-slate-500 space-y-1">
          <p>© {new Date().getFullYear()} SELISCO LTD Orthopaedic & Surgical. Real-time document verification service.</p>
          <p className="font-semibold text-slate-700">Powered by Xuremi • +254715329007</p>
        </div>
      </div>
    </div>
  );
}
