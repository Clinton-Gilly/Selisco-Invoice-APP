import { NextRequest, NextResponse } from 'next/server';
import { query, getClient } from '@/lib/db';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const { id } = params;

    const noteRes = await query(
      `SELECT dn.*, 
              i.invoice_number,
              i.customer_name,
              i.customer_phone,
              i.customer_email,
              i.issued_date as invoice_issued_date,
              b.name as business_name,
              b.phone as business_phone,
              b.email as business_email,
              b.address as business_address,
              b.currency
       FROM delivery_notes dn
       JOIN invoices i ON dn.invoice_id = i.id
       JOIN businesses b ON dn.business_id = b.id
       WHERE dn.id = $1`,
      [id]
    );

    if (noteRes.rows.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Delivery note not found' },
        { status: 404 }
      );
    }

    const itemsRes = await query(
      'SELECT * FROM delivery_note_items WHERE delivery_note_id = $1 ORDER BY created_at ASC',
      [id]
    );

    return NextResponse.json({
      success: true,
      data: {
        ...noteRes.rows[0],
        items: itemsRes.rows,
      },
    });
  } catch (error: any) {
    console.error('Error fetching delivery note:', error);
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
  const client = await getClient();
  try {
    const { id } = params;
    const body = await request.json();
    const { status, recipient_name, recipient_signature_url, notes, delivered_at, items } = body;

    await client.query('BEGIN');

    const fields: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (status) {
      fields.push(`status = $${idx++}`);
      values.push(status);
      if (status === 'DELIVERED' && !delivered_at) {
        fields.push(`delivered_at = CURRENT_TIMESTAMP`);
      }
    }

    if (delivered_at !== undefined) {
      fields.push(`delivered_at = $${idx++}`);
      values.push(delivered_at);
    }

    if (recipient_name !== undefined) {
      fields.push(`recipient_name = $${idx++}`);
      values.push(recipient_name);
    }

    if (recipient_signature_url !== undefined) {
      fields.push(`recipient_signature_url = $${idx++}`);
      values.push(recipient_signature_url);
    }

    if (notes !== undefined) {
      fields.push(`notes = $${idx++}`);
      values.push(notes);
    }

    let updatedNote = null;
    if (fields.length > 0) {
      values.push(id);
      const sql = `UPDATE delivery_notes SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`;
      const updateRes = await client.query(sql, values);
      if (updateRes.rows.length === 0) {
        await client.query('ROLLBACK');
        return NextResponse.json({ success: false, error: 'Delivery note not found' }, { status: 404 });
      }
      updatedNote = updateRes.rows[0];
    } else {
      const getRes = await client.query('SELECT * FROM delivery_notes WHERE id = $1', [id]);
      if (getRes.rows.length === 0) {
        await client.query('ROLLBACK');
        return NextResponse.json({ success: false, error: 'Delivery note not found' }, { status: 404 });
      }
      updatedNote = getRes.rows[0];
    }

    // Update item delivered quantities if provided
    if (items && Array.isArray(items)) {
      for (const item of items) {
        if (item.id && item.delivered_quantity !== undefined) {
          await client.query(
            `UPDATE delivery_note_items 
             SET delivered_quantity = $1 
             WHERE id = $2 AND delivery_note_id = $3`,
            [item.delivered_quantity, item.id, id]
          );
        }
      }
    }

    const itemsRes = await client.query(
      'SELECT * FROM delivery_note_items WHERE delivery_note_id = $1 ORDER BY created_at ASC',
      [id]
    );

    await client.query('COMMIT');

    return NextResponse.json({
      success: true,
      data: {
        ...updatedNote,
        items: itemsRes.rows,
      },
    });
  } catch (error: any) {
    await client.query('ROLLBACK');
    console.error('Error updating delivery note:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to update delivery note' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
}
