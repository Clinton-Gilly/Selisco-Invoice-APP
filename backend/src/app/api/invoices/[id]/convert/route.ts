import { NextRequest, NextResponse } from 'next/server';
import { getClient } from '@/lib/db';

// POST /api/invoices/[id]/convert - 1-click convert invoice to delivery note
export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const client = await getClient();
  try {
    const { id: invoiceId } = params;
    let body = {};
    try {
      body = await request.json();
    } catch {
      // Empty body is allowed for 1-click default conversion
    }

    const { recipient_name, notes } = body as any;

    // Fetch invoice and items
    const invoiceRes = await client.query('SELECT * FROM invoices WHERE id = $1', [invoiceId]);
    if (invoiceRes.rows.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Invoice not found' },
        { status: 404 }
      );
    }

    const invoice = invoiceRes.rows[0];

    const itemsRes = await client.query(
      'SELECT * FROM invoice_items WHERE invoice_id = $1 ORDER BY created_at ASC',
      [invoiceId]
    );

    if (itemsRes.rows.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Invoice has no items to convert to a delivery note.' },
        { status: 400 }
      );
    }

    await client.query('BEGIN');

    // Generate unique note number e.g. DN-2026-0001 or derived from invoice_number
    const countRes = await client.query(
      'SELECT COUNT(*)::int as total FROM delivery_notes WHERE business_id = $1',
      [invoice.business_id]
    );
    const noteSeq = (countRes.rows[0].total + 1).toString().padStart(4, '0');
    const currentYear = new Date().getFullYear();
    const noteNumber = `DN-${currentYear}-${noteSeq}`;

    const insertNoteSql = `
      INSERT INTO delivery_notes (
        invoice_id, business_id, note_number, status, recipient_name, notes
      ) VALUES ($1, $2, $3, 'PENDING', $4, $5)
      RETURNING *;
    `;

    const noteRes = await client.query(insertNoteSql, [
      invoice.id,
      invoice.business_id,
      noteNumber,
      recipient_name || invoice.customer_name,
      notes || `Generated from Invoice ${invoice.invoice_number}`,
    ]);

    const createdNote = noteRes.rows[0];

    // Populate delivery_note_items with ordered_quantity from invoice items
    const noteItems: any[] = [];
    for (const item of itemsRes.rows) {
      const itemRes = await client.query(
        `INSERT INTO delivery_note_items (
          delivery_note_id, invoice_item_id, product_name, ordered_quantity, delivered_quantity
        ) VALUES ($1, $2, $3, $4, $5)
        RETURNING *;`,
        [createdNote.id, item.id, item.product_name, item.quantity, item.quantity]
      );
      noteItems.push(itemRes.rows[0]);
    }

    await client.query('COMMIT');

    return NextResponse.json(
      {
        success: true,
        message: 'Delivery note successfully created from invoice',
        data: {
          ...createdNote,
          items: noteItems,
        },
      },
      { status: 201 }
    );
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Error converting invoice to delivery note:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to convert invoice' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
}
