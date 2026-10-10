import { NextRequest, NextResponse } from 'next/server';
import { getClient } from '@/lib/db';
import { convertQuotationToInvoice, ensureQuotationTables } from '@/lib/quotations';

export const dynamic = 'force-dynamic';

// POST /api/quotations/[id]/convert - Turn an accepted quotation into an invoice
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  await ensureQuotationTables();
  const client = await getClient();
  try {
    const body = await request.json().catch(() => ({}));

    await client.query('BEGIN');
    const quoteRes = await client.query('SELECT * FROM quotations WHERE id = $1 FOR UPDATE', [params.id]);
    if (quoteRes.rows.length === 0) {
      await client.query('ROLLBACK');
      return NextResponse.json({ success: false, error: 'Quotation not found' }, { status: 404 });
    }

    const { invoice } = await convertQuotationToInvoice(client, quoteRes.rows[0], body);
    await client.query('COMMIT');

    return NextResponse.json({ success: true, data: invoice }, { status: 201 });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Failed to convert quotation:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to convert quotation' },
      { status: 400 }
    );
  } finally {
    client.release();
  }
}
