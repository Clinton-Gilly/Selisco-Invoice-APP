import { NextRequest, NextResponse } from 'next/server';
import { query, getClient } from '@/lib/db';
import { generateVerificationToken } from '@/utils/crypto';

export const dynamic = 'force-dynamic';

// GET /api/invoices - List invoices with optional search & status filters
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const status = searchParams.get('status');
    const search = searchParams.get('search');
    const limit = parseInt(searchParams.get('limit') || '50', 10);
    const offset = parseInt(searchParams.get('offset') || '0', 10);

    const conditions: string[] = [];
    const values: any[] = [];
    let paramIndex = 1;

    if (status && status !== 'ALL') {
      conditions.push(`i.status = $${paramIndex++}`);
      values.push(status);
    }

    if (search) {
      conditions.push(`(i.invoice_number ILIKE $${paramIndex} OR i.customer_name ILIKE $${paramIndex} OR i.customer_phone ILIKE $${paramIndex})`);
      values.push(`%${search}%`);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const sql = `
      SELECT 
        i.*,
        b.name as business_name,
        b.currency as currency,
        COUNT(it.id)::int as item_count,
        EXISTS(SELECT 1 FROM delivery_notes dn WHERE dn.invoice_id = i.id) as has_delivery_note
      FROM invoices i
      JOIN businesses b ON i.business_id = b.id
      LEFT JOIN invoice_items it ON i.id = it.invoice_id
      ${whereClause}
      GROUP BY i.id, b.name, b.currency
      ORDER BY i.created_at DESC
      LIMIT $${paramIndex++} OFFSET $${paramIndex++};
    `;

    values.push(limit, offset);
    const result = await query(sql, values);

    return NextResponse.json({
      success: true,
      data: result.rows,
      count: result.rowCount,
    });
  } catch (error: any) {
    console.error('Failed to fetch invoices:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Internal server error' },
      { status: 500 }
    );
  }
}

// POST /api/invoices - Create an invoice with items
export async function POST(request: NextRequest) {
  const client = await getClient();
  try {
    const body = await request.json();
    const {
      business_id,
      customer_name,
      customer_phone,
      customer_email,
      customer_pin,
      status = 'ISSUED',
      items = [],
      tax = 0,
      issued_date,
      due_date,
      notes,
    } = body;

    if (!customer_name || !items || items.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Customer name and at least one item are required.' },
        { status: 400 }
      );
    }

    // Resolve business_id
    let selectedBusinessId = business_id;
    if (!selectedBusinessId) {
      const bizRes = await client.query('SELECT id FROM businesses ORDER BY created_at ASC LIMIT 1');
      if (bizRes.rows.length === 0) {
        return NextResponse.json(
          { success: false, error: 'No business profile found. Please create a business first.' },
          { status: 400 }
        );
      }
      selectedBusinessId = bizRes.rows[0].id;
    }

    // Calculate items totals
    let subtotal = 0;
    const computedItems: Array<{
      product_name: string;
      description?: string;
      quantity: number;
      unit_price: number;
      total_price: number;
    }> = [];

    for (const item of items) {
      const qty = parseFloat(item.quantity) || 1;
      const price = parseFloat(item.unit_price) || 0;
      const total = parseFloat((qty * price).toFixed(2));
      subtotal += total;
      computedItems.push({
        product_name: item.product_name,
        description: item.description || null,
        quantity: qty,
        unit_price: price,
        total_price: total,
      });
    }

    subtotal = parseFloat(subtotal.toFixed(2));
    const computedTax = parseFloat(parseFloat(tax || '0').toFixed(2));
    const totalAmount = parseFloat((subtotal + computedTax).toFixed(2));

    await client.query('BEGIN');

    // Generate sequential invoice number (e.g. INV-2026-000X)
    const countRes = await client.query(
      'SELECT COUNT(*)::int as total FROM invoices WHERE business_id = $1',
      [selectedBusinessId]
    );
    const invoiceSeq = (countRes.rows[0].total + 1).toString().padStart(4, '0');
    const currentYear = new Date().getFullYear();
    const invoiceNumber = `INV-${currentYear}-${invoiceSeq}`;

    const verificationToken = generateVerificationToken();
    const resolvedIssueDate = issued_date || new Date().toISOString().split('T')[0];
    const resolvedDueDate =
      due_date ||
      new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

    const insertInvoiceSql = `
      INSERT INTO invoices (
        business_id, invoice_number, customer_name, customer_phone, customer_email,
        customer_pin, status, subtotal, tax, total_amount, verification_token, issued_date, due_date, notes
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
      RETURNING *;
    `;

    const invoiceRes = await client.query(insertInvoiceSql, [
      selectedBusinessId,
      invoiceNumber,
      customer_name,
      customer_phone || null,
      customer_email || null,
      customer_pin || null,
      status,
      subtotal,
      computedTax,
      totalAmount,
      verificationToken,
      resolvedIssueDate,
      resolvedDueDate,
      notes || null,
    ]);

    const createdInvoice = invoiceRes.rows[0];

    // Insert line items
    const insertedItems: any[] = [];
    for (const it of computedItems) {
      const itemRes = await client.query(
        `INSERT INTO invoice_items (invoice_id, product_name, description, quantity, unit_price, total_price)
         VALUES ($1, $2, $3, $4, $5, $6) RETURNING *;`,
        [createdInvoice.id, it.product_name, it.description, it.quantity, it.unit_price, it.total_price]
      );
      insertedItems.push(itemRes.rows[0]);
    }

    await client.query('COMMIT');

    return NextResponse.json(
      {
        success: true,
        data: {
          ...createdInvoice,
          items: insertedItems,
        },
      },
      { status: 201 }
    );
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Failed to create invoice:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to create invoice' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
}
