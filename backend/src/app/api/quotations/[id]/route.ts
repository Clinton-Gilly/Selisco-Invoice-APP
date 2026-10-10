import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { QUOTATION_STATUSES, ensureQuotationTables } from '@/lib/quotations';

export const dynamic = 'force-dynamic';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    await ensureQuotationTables();
    const { id } = params;

    const quoteRes = await query(
      `SELECT q.*,
              to_char(q.quote_date, 'YYYY-MM-DD') AS quote_date,
              to_char(q.due_date, 'YYYY-MM-DD') AS due_date,
              b.name AS business_name,
              b.currency AS currency,
              i.invoice_number AS invoice_number
       FROM quotations q
       JOIN businesses b ON q.business_id = b.id
       LEFT JOIN invoices i ON q.invoice_id = i.id
       WHERE q.id = $1`,
      [id]
    );

    if (quoteRes.rows.length === 0) {
      return NextResponse.json({ success: false, error: 'Quotation not found' }, { status: 404 });
    }

    const itemsRes = await query(
      'SELECT * FROM quotation_items WHERE quotation_id = $1 ORDER BY created_at ASC',
      [id]
    );

    return NextResponse.json({
      success: true,
      data: { ...quoteRes.rows[0], items: itemsRes.rows },
    });
  } catch (error: any) {
    console.error('Error fetching quotation details:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    await ensureQuotationTables();
    const { id } = params;
    const { status, terms, due_date } = await request.json();

    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (status) {
      const normalized = String(status).toUpperCase();
      if (!(QUOTATION_STATUSES as readonly string[]).includes(normalized) || normalized === 'INVOICED') {
        return NextResponse.json(
          { success: false, error: `Invalid status "${status}".` },
          { status: 400 }
        );
      }
      fields.push(`status = $${idx++}`);
      values.push(normalized);
    }
    if (terms !== undefined) {
      fields.push(`terms = $${idx++}`);
      values.push(terms);
    }
    if (due_date) {
      fields.push(`due_date = $${idx++}`);
      values.push(due_date);
    }

    if (fields.length === 0) {
      return NextResponse.json(
        { success: false, error: 'No fields provided to update' },
        { status: 400 }
      );
    }

    values.push(id);
    const res = await query(
      `UPDATE quotations SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE id = $${idx} RETURNING *`,
      values
    );

    if (res.rows.length === 0) {
      return NextResponse.json({ success: false, error: 'Quotation not found' }, { status: 404 });
    }

    return NextResponse.json({ success: true, data: res.rows[0] });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Update failed' },
      { status: 500 }
    );
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    await ensureQuotationTables();
    const res = await query('DELETE FROM quotations WHERE id = $1 RETURNING id', [params.id]);
    if (res.rows.length === 0) {
      return NextResponse.json({ success: false, error: 'Quotation not found' }, { status: 404 });
    }
    return NextResponse.json({ success: true, message: 'Quotation deleted successfully' });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Delete failed' },
      { status: 500 }
    );
  }
}
