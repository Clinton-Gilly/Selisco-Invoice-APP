import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    // 1. Invoices KPI aggregation
    const invoiceStatsRes = await query(`
      SELECT 
        COALESCE(SUM(CASE WHEN status = 'PAID' THEN total_amount ELSE 0 END), 0)::numeric as total_revenue,
        COALESCE(SUM(CASE WHEN status IN ('ISSUED', 'OVERDUE') THEN total_amount ELSE 0 END), 0)::numeric as pending_amount,
        COALESCE(SUM(total_amount), 0)::numeric as gross_billed,
        COUNT(*)::int as total_invoices,
        COUNT(CASE WHEN status = 'PAID' THEN 1 END)::int as paid_invoices,
        COUNT(CASE WHEN status IN ('ISSUED', 'OVERDUE') THEN 1 END)::int as pending_invoices,
        COUNT(CASE WHEN status = 'OVERDUE' THEN 1 END)::int as overdue_invoices
      FROM invoices;
    `);

    // 2. Deliveries KPI aggregation
    const deliveryStatsRes = await query(`
      SELECT 
        COUNT(*)::int as total_deliveries,
        COUNT(CASE WHEN status = 'DELIVERED' THEN 1 END)::int as delivered_count,
        COUNT(CASE WHEN status = 'IN_TRANSIT' THEN 1 END)::int as in_transit_count,
        COUNT(CASE WHEN status = 'PENDING' THEN 1 END)::int as pending_count,
        COUNT(CASE WHEN status = 'REJECTED' THEN 1 END)::int as rejected_count
      FROM delivery_notes;
    `);

    // 3. Monthly revenue trend for the last 6 months
    const monthlyTrendsRes = await query(`
      SELECT 
        TO_CHAR(DATE_TRUNC('month', issued_date), 'Mon YYYY') as month,
        DATE_TRUNC('month', issued_date) as sort_date,
        COALESCE(SUM(total_amount), 0)::numeric as revenue,
        COUNT(*)::int as count
      FROM invoices
      WHERE issued_date >= CURRENT_DATE - INTERVAL '6 months'
      GROUP BY DATE_TRUNC('month', issued_date), TO_CHAR(DATE_TRUNC('month', issued_date), 'Mon YYYY')
      ORDER BY sort_date ASC;
    `);

    const invStats = invoiceStatsRes.rows[0] || {};
    const delStats = deliveryStatsRes.rows[0] || {};

    const totalDeliveries = parseInt(delStats.total_deliveries || '0', 10);
    const deliveredCount = parseInt(delStats.delivered_count || '0', 10);
    const deliverySuccessRate =
      totalDeliveries > 0
        ? parseFloat(((deliveredCount / totalDeliveries) * 100).toFixed(1))
        : 100.0;

    return NextResponse.json({
      success: true,
      data: {
        total_revenue: parseFloat(invStats.total_revenue || '0'),
        pending_amount: parseFloat(invStats.pending_amount || '0'),
        gross_billed: parseFloat(invStats.gross_billed || '0'),
        total_invoices: parseInt(invStats.total_invoices || '0', 10),
        paid_invoices: parseInt(invStats.paid_invoices || '0', 10),
        pending_invoices: parseInt(invStats.pending_invoices || '0', 10),
        overdue_invoices: parseInt(invStats.overdue_invoices || '0', 10),
        total_deliveries: totalDeliveries,
        delivered_count: deliveredCount,
        in_transit_count: parseInt(delStats.in_transit_count || '0', 10),
        pending_deliveries: parseInt(delStats.pending_count || '0', 10),
        rejected_deliveries: parseInt(delStats.rejected_count || '0', 10),
        delivery_success_rate: deliverySuccessRate,
        monthly_trends: monthlyTrendsRes.rows.map((row) => ({
          month: row.month,
          revenue: parseFloat(row.revenue),
          count: parseInt(row.count, 10),
        })),
      },
    });
  } catch (error: any) {
    console.error('Error fetching analytics:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to fetch analytics' },
      { status: 500 }
    );
  }
}
