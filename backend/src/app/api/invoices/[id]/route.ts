import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;

    const invoiceRes = await query(
      `SELECT i.*, 
              b.name as business_name, 
              b.email as business_email, 
              b.phone as business_phone, 
              b.currency as currency, 
              b.address as business_address, 
              b.logo_url as business_logo_url
       FROM invoices i
       JOIN businesses b ON i.business_id = b.id
       WHERE i.id = $1`,
      [id]
    );

    if (invoiceRes.rows.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Invoice not found' },
        { status: 404 }
      );
    }

    const itemsRes = await query(
      'SELECT * FROM invoice_items WHERE invoice_id = $1 ORDER BY created_at ASC',
      [id]
    );

    const deliveryNotesRes = await query(
      'SELECT * FROM delivery_notes WHERE invoice_id = $1 ORDER BY created_at DESC',
      [id]
    );

    return NextResponse.json({
      success: true,
      data: {
        ...invoiceRes.rows[0],
        items: itemsRes.rows,
        delivery_notes: deliveryNotesRes.rows,
      },
    });
  } catch (error: any) {
    console.error('Error fetching invoice details:', error);
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
    const { id } = params;
    const body = await request.json();
    const { status, notes, due_date } = body;

    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (status) {
      fields.push(`status = $${idx++}`);
      values.push(status);
    }
    if (notes !== undefined) {
      fields.push(`notes = $${idx++}`);
      values.push(notes);
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
    const sql = `UPDATE invoices SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`;
    const res = await query(sql, values);

    if (res.rows.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Invoice not found' },
        { status: 404 }
      );
    }

    return NextResponse.json({
      success: true,
      data: res.rows[0],
    });
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
    const { id } = params;
    const res = await query('DELETE FROM invoices WHERE id = $1 RETURNING id', [id]);
    if (res.rows.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Invoice not found' },
        { status: 404 }
      );
    }
    return NextResponse.json({ success: true, message: 'Invoice deleted successfully' });
  } catch (error: any) {
    return NextResponse.json(
      { success: false, error: error.message || 'Delete failed' },
      { status: 500 }
    );
  }
}
