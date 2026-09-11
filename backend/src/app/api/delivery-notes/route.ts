import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status');
    const search = searchParams.get('search');

    const conditions: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (status && status !== 'ALL') {
      conditions.push(`dn.status = $${idx++}`);
      values.push(status);
    }

    if (search) {
      conditions.push(`(dn.note_number ILIKE $${idx} OR dn.recipient_name ILIKE $${idx} OR i.invoice_number ILIKE $${idx})`);
      values.push(`%${search}%`);
      idx++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const sql = `
      SELECT 
        dn.*,
        i.invoice_number,
        i.customer_name,
        i.customer_phone,
        b.name as business_name,
        COUNT(dni.id)::int as item_count,
        SUM(dni.ordered_quantity)::numeric as total_ordered_quantity,
        SUM(dni.delivered_quantity)::numeric as total_delivered_quantity
      FROM delivery_notes dn
      JOIN invoices i ON dn.invoice_id = i.id
      JOIN businesses b ON dn.business_id = b.id
      LEFT JOIN delivery_note_items dni ON dn.id = dni.delivery_note_id
      ${whereClause}
      GROUP BY dn.id, i.invoice_number, i.customer_name, i.customer_phone, b.name
      ORDER BY dn.created_at DESC;
    `;

    const res = await query(sql, values);

    return NextResponse.json({
      success: true,
      data: res.rows,
      count: res.rowCount,
    });
  } catch (error: any) {
    console.error('Error fetching delivery notes:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to fetch delivery notes' },
      { status: 500 }
    );
  }
}
