import { NextRequest, NextResponse } from 'next/server';
import { query, getClient } from '@/lib/db';
import { ensureQuotationTables, insertQuotation, resolveBusinessId } from '@/lib/quotations';

export const dynamic = 'force-dynamic';

// GET /api/quotations - List quotations with optional status & search filters
export async function GET(request: NextRequest) {
  try {
    await ensureQuotationTables();
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status');
    const search = searchParams.get('search');
    const limit = parseInt(searchParams.get('limit') || '50', 10);
    const offset = parseInt(searchParams.get('offset') || '0', 10);

    const conditions: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    if (status && status !== 'ALL') {
      conditions.push(`q.status = $${paramIndex++}`);
      values.push(status);
    }

    if (search) {
      conditions.push(
        `(q.quote_number ILIKE $${paramIndex} OR q.customer_name ILIKE $${paramIndex} OR q.customer_phone ILIKE $${paramIndex})`
      );
      values.push(`%${search}%`);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const sql = `
      SELECT
        q.*,
        to_char(q.quote_date, 'YYYY-MM-DD') AS quote_date,
        to_char(q.due_date, 'YYYY-MM-DD') AS due_date,
        b.name AS business_name,
        b.currency AS currency,
        COUNT(qi.id)::int AS item_count
      FROM quotations q
      JOIN businesses b ON q.business_id = b.id
      LEFT JOIN quotation_items qi ON q.id = qi.quotation_id
      ${whereClause}
      GROUP BY q.id, b.name, b.currency
      ORDER BY q.created_at DESC
      LIMIT $${paramIndex++} OFFSET $${paramIndex++};
    `;

    values.push(limit, offset);
    const result = await query(sql, values);

    return NextResponse.json({ success: true, data: result.rows, count: result.rowCount });
  } catch (error: any) {
    console.error('Failed to fetch quotations:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}

// POST /api/quotations - Create a quotation with items
export async function POST(request: NextRequest) {
  await ensureQuotationTables();
  const client = await getClient();
  try {
    const body = await request.json();
    const businessId = await resolveBusinessId(client, body.business_id);

    await client.query('BEGIN');
    const quotation = await insertQuotation(client, businessId, body);
    await client.query('COMMIT');

    return NextResponse.json({ success: true, data: quotation }, { status: 201 });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Failed to create quotation:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to create quotation' },
      { status: 400 }
    );
  } finally {
    client.release();
  }
}
