import { NextRequest, NextResponse } from 'next/server';
import { getClient } from '@/lib/db';

export const dynamic = 'force-dynamic';

type Db = { query: (text: string, params?: any[]) => Promise<{ rows: any[] }> };

async function restoreRows(db: Db, table: string, rows: any[] | null | undefined) {
  for (const row of rows || []) {
    await db.query(`INSERT INTO ${table} SELECT * FROM json_populate_record(NULL::${table}, $1)`, [
      JSON.stringify(row),
    ]);
  }
}

/**
 * Reverses a copilot action using the state captured when it ran.
 * Returns a human-readable message, or throws if it cannot be reversed.
 */
async function revert(db: Db, log: any): Promise<string> {
  const result = log.result || {};
  const params = log.parameters || {};
  const targetId = log.target_id;

  switch (log.action_name) {
    case 'create_invoice':
      await db.query('DELETE FROM invoices WHERE id = $1 AND business_id = $2', [targetId, log.business_id]);
      return `Invoice ${result.invoice_number || ''} removed.`;

    case 'convert_invoice_to_delivery_note':
      await db.query('DELETE FROM delivery_notes WHERE id = $1 AND business_id = $2', [targetId, log.business_id]);
      return `Delivery note ${result.note_number || ''} removed.`;

    case 'save_product':
      if (result.previous) {
        await db.query(
          'UPDATE products SET unit_price = $1, item_code = $2, tax_type = $3 WHERE id = $4 AND business_id = $5',
          [result.previous.unit_price, result.previous.item_code, result.previous.tax_type, targetId, log.business_id]
        );
        return `Product "${result.name || params.name}" restored to its previous price.`;
      }
      if (result.action === 'created_product') {
        await db.query('DELETE FROM products WHERE id = $1 AND business_id = $2', [targetId, log.business_id]);
        return `Product "${result.name || params.name}" removed from the catalog.`;
      }
      // Logged before previous state was captured: unknown whether it was new or an update.
      throw new Error('This product change was recorded without its previous values and cannot be undone automatically.');

    case 'update_invoice_status':
      if (!result.previous_status) {
        throw new Error('Previous status was not recorded; please change the status manually.');
      }
      await db.query(
        'UPDATE invoices SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND business_id = $3',
        [result.previous_status, targetId, log.business_id]
      );
      return `Invoice ${result.invoice_number || ''} set back to ${result.previous_status}.`;

    case 'update_delivery_status':
      if (!result.previous) {
        throw new Error('Previous status was not recorded; please change the status manually.');
      }
      await db.query(
        `UPDATE delivery_notes SET status = $1, delivered_at = $2, recipient_name = $3, updated_at = CURRENT_TIMESTAMP
         WHERE id = $4 AND business_id = $5`,
        [result.previous.status, result.previous.delivered_at, result.previous.recipient_name, targetId, log.business_id]
      );
      return `Delivery note ${result.note_number || ''} set back to ${result.previous.status}.`;

    case 'create_quotation':
      await db.query('DELETE FROM quotations WHERE id = $1 AND business_id = $2', [targetId, log.business_id]);
      return `Quotation ${result.quote_number || ''} removed.`;

    case 'update_quotation_status':
      if (!result.previous_status) {
        throw new Error('Previous status was not recorded; please change the status manually.');
      }
      await db.query(
        'UPDATE quotations SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND business_id = $3',
        [result.previous_status, targetId, log.business_id]
      );
      return `Quotation ${result.quote_number || ''} set back to ${result.previous_status}.`;

    case 'convert_quotation_to_invoice':
      await db.query('DELETE FROM invoices WHERE id = $1 AND business_id = $2', [targetId, log.business_id]);
      await db.query(
        'UPDATE quotations SET status = $1, invoice_id = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND business_id = $3',
        [result.previous_quote_status || 'ACCEPTED', result.quotation_id, log.business_id]
      );
      return `Invoice ${result.invoice_number || ''} removed and quotation ${result.quote_number || ''} reopened.`;

    case 'delete_invoice': {
      const snap = result.snapshot;
      if (!snap?.invoice) {
        throw new Error('The deleted invoice was not backed up, so it cannot be restored.');
      }
      await restoreRows(db, 'invoices', [snap.invoice]);
      await restoreRows(db, 'invoice_items', snap.invoice_items);
      await restoreRows(db, 'delivery_notes', snap.delivery_notes);
      await restoreRows(db, 'delivery_note_items', snap.delivery_note_items);
      return `Invoice ${result.invoice_number || ''} restored.`;
    }

    default:
      throw new Error(`Undo is not supported for "${log.action_name}".`);
  }
}

export async function POST(request: NextRequest) {
  const client = await getClient();
  try {
    const body = await request.json();
    const { audit_log_id } = body;

    if (!audit_log_id) {
      return NextResponse.json(
        { success: false, error: 'Audit log ID is required to perform undo.' },
        { status: 400 }
      );
    }

    const auditRes = await client.query('SELECT * FROM copilot_audit_logs WHERE id = $1 LIMIT 1', [
      audit_log_id,
    ]);

    if (auditRes.rows.length === 0) {
      return NextResponse.json(
        { success: false, error: 'Audit log entry not found.' },
        { status: 404 }
      );
    }

    const log = auditRes.rows[0];

    if (log.undone) {
      return NextResponse.json(
        { success: false, error: 'This action has already been undone.' },
        { status: 400 }
      );
    }

    if (!log.target_id) {
      return NextResponse.json(
        { success: false, error: 'This action cannot be automatically undone.' },
        { status: 400 }
      );
    }

    let message: string;
    try {
      await client.query('BEGIN');
      message = await revert(client, log);
      await client.query('UPDATE copilot_audit_logs SET undone = true WHERE id = $1', [audit_log_id]);
      await client.query('COMMIT');
    } catch (err: any) {
      await client.query('ROLLBACK');
      return NextResponse.json({ success: false, error: err.message }, { status: 400 });
    }

    return NextResponse.json({ success: true, message: `Undone: ${message}` });
  } catch (error: any) {
    console.error('Failed to undo copilot action:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to undo action' },
      { status: 500 }
    );
  } finally {
    client.release();
  }
}
