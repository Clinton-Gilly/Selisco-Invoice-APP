import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { audit_log_id } = body;

    if (!audit_log_id) {
      return NextResponse.json(
        { success: false, error: 'Audit log ID is required to perform undo.' },
        { status: 400 }
      );
    }

    const auditRes = await query('SELECT * FROM copilot_audit_logs WHERE id = $1 LIMIT 1', [
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

    const targetEntity = log.target_entity;
    const targetId = log.target_id;

    if (!targetEntity || !targetId) {
      return NextResponse.json(
        { success: false, error: 'This action cannot be automatically undone.' },
        { status: 400 }
      );
    }

    // Revert based on entity
    if (targetEntity === 'invoices') {
      await query('DELETE FROM invoices WHERE id = $1', [targetId]);
    } else if (targetEntity === 'products') {
      await query('DELETE FROM products WHERE id = $1', [targetId]);
    } else if (targetEntity === 'delivery_notes') {
      await query('DELETE FROM delivery_notes WHERE id = $1', [targetId]);
    } else {
      return NextResponse.json(
        { success: false, error: `Undo not supported for entity type "${targetEntity}".` },
        { status: 400 }
      );
    }

    // Mark as undone
    await query('UPDATE copilot_audit_logs SET undone = true WHERE id = $1', [audit_log_id]);

    return NextResponse.json({
      success: true,
      message: `Action undone: ${log.description}`,
    });
  } catch (error: any) {
    console.error('Failed to undo copilot action:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to undo action' },
      { status: 500 }
    );
  }
}
