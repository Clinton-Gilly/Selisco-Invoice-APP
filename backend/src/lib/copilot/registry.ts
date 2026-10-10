import { query, getClient } from '@/lib/db';
import { generateVerificationToken } from '@/utils/crypto';
import { nextDocumentNumber } from '@/lib/numbering';
import {
  QUOTATION_STATUSES,
  convertQuotationToInvoice,
  ensureQuotationTables,
  insertQuotation,
} from '@/lib/quotations';
import { ToolContext, ToolDef } from './types';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const INVOICE_STATUSES = ['DRAFT', 'ISSUED', 'PAID', 'OVERDUE', 'CANCELLED'];
const DELIVERY_STATUSES = ['PENDING', 'IN_TRANSIT', 'DELIVERED', 'REJECTED'];

function money(ctx: ToolContext, value: any): string {
  return `${ctx.currency} ${Number(value || 0).toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

/** Models often send ids in the wrong field or wrong case; normalise defensively. */
function validId(id: any): string | undefined {
  return typeof id === 'string' && UUID_RE.test(id.trim()) ? id.trim() : undefined;
}

function normStatus(value: any, allowed: string[]): string {
  const s = String(value || '').trim().toUpperCase().replace(/[\s-]+/g, '_');
  if (!allowed.includes(s)) {
    throw new Error(`Invalid status "${value}". Must be one of: ${allowed.join(', ')}`);
  }
  return s;
}

type RunSql = (text: string, params?: any[]) => Promise<{ rows: any[] }>;

async function findInvoice(run: RunSql, ctx: ToolContext, id?: any, invoiceNumber?: any) {
  const uuid = validId(id);
  if (uuid) {
    const r = await run('SELECT * FROM invoices WHERE id = $1 AND business_id = $2', [uuid, ctx.businessId]);
    if (r.rows[0]) return r.rows[0];
  }
  // Accept an invoice number passed in either field
  const num = String(invoiceNumber || (!uuid && id) || '').trim();
  if (!num) {
    if (!uuid) throw new Error('Provide invoice_number (e.g. INV-2026-0001) or the invoice id.');
    return undefined;
  }
  const r = await run('SELECT * FROM invoices WHERE invoice_number ILIKE $1 AND business_id = $2', [
    num,
    ctx.businessId,
  ]);
  return r.rows[0];
}

async function findQuotation(run: RunSql, ctx: ToolContext, id?: any, quoteNumber?: any) {
  await ensureQuotationTables();
  const uuid = validId(id);
  if (uuid) {
    const r = await run('SELECT * FROM quotations WHERE id = $1 AND business_id = $2', [uuid, ctx.businessId]);
    if (r.rows[0]) return r.rows[0];
  }
  const num = String(quoteNumber || (!uuid && id) || '').trim();
  if (!num) {
    if (!uuid) throw new Error('Provide quote_number (e.g. QT-2026-0001) or the quotation id.');
    return undefined;
  }
  const r = await run('SELECT * FROM quotations WHERE quote_number ILIKE $1 AND business_id = $2', [
    num,
    ctx.businessId,
  ]);
  return r.rows[0];
}

async function findDeliveryNote(run: RunSql, ctx: ToolContext, id?: any, noteNumber?: any) {
  const uuid = validId(id);
  if (uuid) {
    const r = await run('SELECT * FROM delivery_notes WHERE id = $1 AND business_id = $2', [uuid, ctx.businessId]);
    if (r.rows[0]) return r.rows[0];
  }
  const num = String(noteNumber || (!uuid && id) || '').trim();
  if (!num) {
    if (!uuid) throw new Error('Provide note_number (e.g. DN-2026-0001) or the delivery note id.');
    return undefined;
  }
  const r = await run('SELECT * FROM delivery_notes WHERE note_number ILIKE $1 AND business_id = $2', [
    num,
    ctx.businessId,
  ]);
  return r.rows[0];
}

export const TOOL_REGISTRY: Record<string, ToolDef> = {
  // ==========================================
  // READ TOOLS
  // ==========================================

  list_invoices: {
    name: 'list_invoices',
    description:
      'Search and list invoices for the organization. Returns up to 20 invoices with customer name, status, total amount, and dates.',
    parameters: {
      type: 'object',
      properties: {
        status: {
          type: 'string',
          enum: ['ALL', 'UNPAID', 'DRAFT', 'ISSUED', 'PAID', 'OVERDUE', 'CANCELLED'],
          description:
            'Filter by status. UNPAID = ISSUED or OVERDUE. OVERDUE also includes ISSUED invoices past their due date. Default ALL.',
        },
        search: {
          type: 'string',
          description: 'Optional search text for customer name, phone, or invoice number',
        },
        limit: {
          type: 'number',
          description: 'Max records to return (default 10, max 20)',
        },
      },
    },
    writes: false,
    describe: () => 'List invoices',
    run: async (ctx: ToolContext, args: any) => {
      const { status, search, limit = 10 } = args;
      const conditions: string[] = ['i.business_id = $1'];
      const values: any[] = [ctx.businessId];
      let pIdx = 2;

      const st = String(status || 'ALL').trim().toUpperCase();
      if (st === 'UNPAID') {
        conditions.push(`i.status IN ('ISSUED', 'OVERDUE')`);
      } else if (st === 'OVERDUE') {
        conditions.push(`(i.status = 'OVERDUE' OR (i.status = 'ISSUED' AND i.due_date < CURRENT_DATE))`);
      } else if (st !== 'ALL') {
        conditions.push(`i.status = $${pIdx++}`);
        values.push(normStatus(st, INVOICE_STATUSES));
      }

      if (search && String(search).trim()) {
        conditions.push(
          `(i.invoice_number ILIKE $${pIdx} OR i.customer_name ILIKE $${pIdx} OR i.customer_phone ILIKE $${pIdx})`
        );
        values.push(`%${String(search).trim()}%`);
        pIdx++;
      }

      const cappedLimit = Math.min(Math.max(1, Number(limit) || 10), 20);
      values.push(cappedLimit);

      const sql = `
        SELECT 
          i.id, i.invoice_number, i.customer_name, i.customer_phone,
          i.status, i.total_amount, to_char(i.issued_date, 'YYYY-MM-DD') as issued_date,
          to_char(i.due_date, 'YYYY-MM-DD') as due_date,
          (i.status IN ('ISSUED', 'OVERDUE') AND i.due_date < CURRENT_DATE) as is_overdue,
          COUNT(it.id)::int as item_count
        FROM invoices i
        LEFT JOIN invoice_items it ON i.id = it.invoice_id
        WHERE ${conditions.join(' AND ')}
        GROUP BY i.id
        ORDER BY i.created_at DESC
        LIMIT $${pIdx};
      `;

      const res = await query(sql, values);
      const sum = res.rows.reduce((acc: number, r: any) => acc + Number(r.total_amount || 0), 0);
      return {
        total_found: res.rows.length,
        sum_of_listed_totals: money(ctx, sum),
        invoices: res.rows.map((row) => ({
          ...row,
          total_amount: Number(row.total_amount),
          total_amount_formatted: money(ctx, row.total_amount),
        })),
      };
    },
  },

  get_invoice: {
    name: 'get_invoice',
    description:
      'Retrieve full details of a specific invoice including customer information, line items, and delivery note status.',
    parameters: {
      type: 'object',
      properties: {
        invoice_number: {
          type: 'string',
          description: 'Invoice number (e.g. INV-2026-0001)',
        },
        id: {
          type: 'string',
          description: 'Unique UUID of the invoice',
        },
      },
    },
    writes: false,
    describe: () => 'Get invoice details',
    run: async (ctx: ToolContext, args: any) => {
      const invoice = await findInvoice(query, ctx, args.id, args.invoice_number);
      if (!invoice) {
        return { found: false, message: 'Invoice not found. Use list_invoices to search by customer name.' };
      }

      const itemsRes = await query(
        'SELECT product_name, description, quantity, unit_price, total_price FROM invoice_items WHERE invoice_id = $1 ORDER BY created_at ASC',
        [invoice.id]
      );

      const dnRes = await query(
        'SELECT id, note_number, status FROM delivery_notes WHERE invoice_id = $1',
        [invoice.id]
      );

      // Format dates in the database so the server timezone can't shift them by a day
      const dates = await query(
        `SELECT to_char(issued_date, 'YYYY-MM-DD') AS issued_date, to_char(due_date, 'YYYY-MM-DD') AS due_date,
                due_date < CURRENT_DATE AS past_due
         FROM invoices WHERE id = $1`,
        [invoice.id]
      );

      return {
        found: true,
        invoice: {
          id: invoice.id,
          invoice_number: invoice.invoice_number,
          customer_name: invoice.customer_name,
          customer_phone: invoice.customer_phone,
          customer_email: invoice.customer_email,
          customer_pin: invoice.customer_pin,
          status: invoice.status,
          subtotal: Number(invoice.subtotal),
          tax: Number(invoice.tax),
          total_amount: Number(invoice.total_amount),
          formatted_total: money(ctx, invoice.total_amount),
          issued_date: dates.rows[0]?.issued_date,
          due_date: dates.rows[0]?.due_date,
          is_overdue: ['ISSUED', 'OVERDUE'].includes(invoice.status) && Boolean(dates.rows[0]?.past_due),
          notes: invoice.notes,
          items: itemsRes.rows,
          delivery_notes: dnRes.rows,
        },
      };
    },
  },

  search_products: {
    name: 'search_products',
    description:
      'Search the medical/surgical product catalog for items, unit prices, product codes, and tax classifications.',
    parameters: {
      type: 'object',
      properties: {
        search: {
          type: 'string',
          description: 'Product name or code search query (e.g. "plate", "screw", "cortical", "drill")',
        },
        limit: {
          type: 'number',
          description: 'Maximum products to return (default 15, max 30)',
        },
      },
    },
    writes: false,
    describe: () => 'Search product catalog',
    run: async (ctx: ToolContext, args: any) => {
      const { search, limit = 15 } = args;
      const capped = Math.min(Math.max(1, limit), 30);

      let sql = 'SELECT id, item_code, name, unit_price, tax_type FROM products WHERE business_id = $1';
      const values: any[] = [ctx.businessId];

      if (search && search.trim()) {
        sql += ' AND (name ILIKE $2 OR item_code ILIKE $2) ORDER BY name ASC LIMIT $3';
        values.push(`%${search.trim()}%`, capped);
      } else {
        sql += ' ORDER BY name ASC LIMIT $2';
        values.push(capped);
      }

      const res = await query(sql, values);
      return {
        count: res.rows.length,
        products: res.rows.map((p) => ({
          ...p,
          formatted_price: `${ctx.currency} ${Number(p.unit_price).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
        })),
      };
    },
  },

  list_delivery_notes: {
    name: 'list_delivery_notes',
    description:
      'List delivery notes with tracking status (PENDING, IN_TRANSIT, DELIVERED, REJECTED) and recipient details.',
    parameters: {
      type: 'object',
      properties: {
        status: {
          type: 'string',
          enum: ['ALL', ...DELIVERY_STATUSES],
          description: 'Filter by status (default ALL)',
        },
        search: {
          type: 'string',
          description: 'Search by note number, invoice number, recipient or customer name',
        },
        limit: {
          type: 'number',
          description: 'Max records (default 10, max 20)',
        },
      },
    },
    writes: false,
    describe: () => 'List delivery notes',
    run: async (ctx: ToolContext, args: any) => {
      const { status, search, limit = 10 } = args;
      const conditions: string[] = ['dn.business_id = $1'];
      const values: any[] = [ctx.businessId];
      let pIdx = 2;

      const st = String(status || 'ALL').trim().toUpperCase();
      if (st !== 'ALL') {
        conditions.push(`dn.status = $${pIdx++}`);
        values.push(normStatus(st, DELIVERY_STATUSES));
      }

      if (search && String(search).trim()) {
        conditions.push(
          `(dn.note_number ILIKE $${pIdx} OR dn.recipient_name ILIKE $${pIdx} OR i.invoice_number ILIKE $${pIdx} OR i.customer_name ILIKE $${pIdx})`
        );
        values.push(`%${String(search).trim()}%`);
        pIdx++;
      }

      const capped = Math.min(Math.max(1, Number(limit) || 10), 20);
      values.push(capped);

      const sql = `
        SELECT 
          dn.id, dn.note_number, dn.status, dn.recipient_name,
          dn.subtotal, dn.tax, dn.total_amount,
          dn.dispatched_at, dn.delivered_at, i.invoice_number, i.customer_name
        FROM delivery_notes dn
        JOIN invoices i ON dn.invoice_id = i.id
        WHERE ${conditions.join(' AND ')}
        ORDER BY dn.created_at DESC
        LIMIT $${pIdx};
      `;

      const res = await query(sql, values);
      const rows = res.rows.map((r: any) => ({
        ...r,
        formatted_total: `${ctx.currency} ${Number(r.total_amount || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
      }));

      return {
        count: rows.length,
        delivery_notes: rows,
      };
    },
  },

  get_delivery_note: {
    name: 'get_delivery_note',
    description:
      'Retrieve full details of one delivery note: status, recipient, linked invoice, amounts, and items with ordered vs delivered quantities.',
    parameters: {
      type: 'object',
      properties: {
        note_number: { type: 'string', description: 'Delivery note number (e.g. DN-2026-0001)' },
        delivery_note_id: { type: 'string', description: 'UUID of the delivery note' },
      },
    },
    writes: false,
    describe: () => 'Get delivery note details',
    run: async (ctx: ToolContext, args: any) => {
      const dn = await findDeliveryNote(query, ctx, args.delivery_note_id, args.note_number);
      if (!dn) {
        return { found: false, message: 'Delivery note not found. Use list_delivery_notes to search.' };
      }
      const inv = await query('SELECT invoice_number, customer_name FROM invoices WHERE id = $1', [dn.invoice_id]);
      const items = await query(
        `SELECT product_name, ordered_quantity, delivered_quantity, unit_price, total_price
         FROM delivery_note_items WHERE delivery_note_id = $1 ORDER BY created_at ASC`,
        [dn.id]
      );
      return {
        found: true,
        delivery_note: {
          id: dn.id,
          note_number: dn.note_number,
          status: dn.status,
          recipient_name: dn.recipient_name,
          invoice_number: inv.rows[0]?.invoice_number,
          customer_name: inv.rows[0]?.customer_name,
          notes: dn.notes,
          total_amount: Number(dn.total_amount || 0),
          formatted_total: money(ctx, dn.total_amount),
          dispatched_at: dn.dispatched_at,
          delivered_at: dn.delivered_at,
          items: items.rows,
        },
      };
    },
  },

  list_quotations: {
    name: 'list_quotations',
    description:
      'Search and list price quotations sent to customers, with quote number, customer, status (DRAFT, SENT, ACCEPTED, DECLINED, INVOICED), total and dates.',
    parameters: {
      type: 'object',
      properties: {
        status: {
          type: 'string',
          enum: ['ALL', ...QUOTATION_STATUSES],
          description: 'Filter by status (default ALL). INVOICED = already converted to an invoice.',
        },
        search: { type: 'string', description: 'Search quote number, customer name or phone' },
        limit: { type: 'number', description: 'Max records (default 10, max 20)' },
      },
    },
    writes: false,
    describe: () => 'List quotations',
    run: async (ctx: ToolContext, args: any) => {
      await ensureQuotationTables();
      const conditions: string[] = ['q.business_id = $1'];
      const values: any[] = [ctx.businessId];
      let pIdx = 2;

      const st = String(args.status || 'ALL').trim().toUpperCase();
      if (st !== 'ALL') {
        conditions.push(`q.status = $${pIdx++}`);
        values.push(normStatus(st, [...QUOTATION_STATUSES]));
      }
      if (args.search && String(args.search).trim()) {
        conditions.push(
          `(q.quote_number ILIKE $${pIdx} OR q.customer_name ILIKE $${pIdx} OR q.customer_phone ILIKE $${pIdx})`
        );
        values.push(`%${String(args.search).trim()}%`);
        pIdx++;
      }
      values.push(Math.min(Math.max(1, Number(args.limit) || 10), 20));

      const res = await query(
        `SELECT q.id, q.quote_number, q.customer_name, q.status, q.total_amount,
                to_char(q.quote_date, 'YYYY-MM-DD') AS quote_date,
                to_char(q.due_date, 'YYYY-MM-DD') AS due_date,
                COUNT(qi.id)::int AS item_count
         FROM quotations q
         LEFT JOIN quotation_items qi ON qi.quotation_id = q.id
         WHERE ${conditions.join(' AND ')}
         GROUP BY q.id
         ORDER BY q.created_at DESC
         LIMIT $${pIdx}`,
        values
      );
      const sum = res.rows.reduce((acc: number, r: any) => acc + Number(r.total_amount || 0), 0);
      return {
        total_found: res.rows.length,
        sum_of_listed_totals: money(ctx, sum),
        quotations: res.rows.map((r: any) => ({
          ...r,
          total_amount: Number(r.total_amount),
          total_amount_formatted: money(ctx, r.total_amount),
        })),
      };
    },
  },

  get_quotation: {
    name: 'get_quotation',
    description: 'Retrieve full details of one quotation including customer, line items, totals and linked invoice.',
    parameters: {
      type: 'object',
      properties: {
        quote_number: { type: 'string', description: 'Quotation number (e.g. QT-2026-0001)' },
        quotation_id: { type: 'string', description: 'UUID of the quotation' },
      },
    },
    writes: false,
    describe: () => 'Get quotation details',
    run: async (ctx: ToolContext, args: any) => {
      const q = await findQuotation(query, ctx, args.quotation_id, args.quote_number);
      if (!q) return { found: false, message: 'Quotation not found. Use list_quotations to search.' };
      const items = await query(
        'SELECT product_name, description, quantity, unit_price, total_price FROM quotation_items WHERE quotation_id = $1 ORDER BY created_at ASC',
        [q.id]
      );
      const extra = await query(
        `SELECT to_char(q.quote_date, 'YYYY-MM-DD') AS quote_date, to_char(q.due_date, 'YYYY-MM-DD') AS due_date,
                i.invoice_number
         FROM quotations q LEFT JOIN invoices i ON i.id = q.invoice_id WHERE q.id = $1`,
        [q.id]
      );
      return {
        found: true,
        quotation: {
          id: q.id,
          quote_number: q.quote_number,
          customer_name: q.customer_name,
          customer_phone: q.customer_phone,
          customer_email: q.customer_email,
          status: q.status,
          subtotal: Number(q.subtotal),
          tax: Number(q.tax),
          total_amount: Number(q.total_amount),
          formatted_total: money(ctx, q.total_amount),
          quote_date: extra.rows[0]?.quote_date,
          due_date: extra.rows[0]?.due_date,
          converted_invoice_number: extra.rows[0]?.invoice_number || null,
          terms: q.terms,
          items: items.rows,
        },
      };
    },
  },

  get_analytics_summary: {
    name: 'get_analytics_summary',
    description:
      'Retrieve high-level business intelligence: total revenue, pending amounts, invoice counts, and delivery performance.',
    parameters: {
      type: 'object',
      properties: {},
    },
    writes: false,
    describe: () => 'Get revenue and delivery analytics',
    run: async (ctx: ToolContext) => {
      const invStats = await query(
        `SELECT
          COALESCE(SUM(CASE WHEN status = 'PAID' THEN total_amount ELSE 0 END), 0) as total_revenue,
          COALESCE(SUM(CASE WHEN status IN ('ISSUED', 'OVERDUE') THEN total_amount ELSE 0 END), 0) as pending_amount,
          COUNT(*)::int as total_invoices,
          COUNT(CASE WHEN status = 'PAID' THEN 1 END)::int as paid_invoices,
          COUNT(CASE WHEN status IN ('ISSUED', 'OVERDUE') THEN 1 END)::int as pending_invoices,
          COUNT(CASE WHEN status IN ('ISSUED', 'OVERDUE') AND due_date < CURRENT_DATE THEN 1 END)::int as overdue_invoices,
          COALESCE(SUM(CASE WHEN status IN ('ISSUED', 'OVERDUE') AND due_date < CURRENT_DATE THEN total_amount ELSE 0 END), 0) as overdue_amount,
          COALESCE(SUM(CASE WHEN status <> 'CANCELLED' AND date_trunc('month', issued_date) = date_trunc('month', CURRENT_DATE) THEN total_amount ELSE 0 END), 0) as invoiced_this_month
        FROM invoices WHERE business_id = $1`,
        [ctx.businessId]
      );

      const delStats = await query(
        `SELECT
          COUNT(*)::int as total_deliveries,
          COUNT(CASE WHEN status = 'DELIVERED' THEN 1 END)::int as delivered_count
        FROM delivery_notes WHERE business_id = $1`,
        [ctx.businessId]
      );

      const invRow = invStats.rows[0];
      const delRow = delStats.rows[0];
      const successRate =
        delRow.total_deliveries > 0
          ? Math.round((delRow.delivered_count / delRow.total_deliveries) * 100)
          : 0;

      return {
        total_revenue: `${ctx.currency} ${Number(invRow.total_revenue).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
        pending_amount: `${ctx.currency} ${Number(invRow.pending_amount).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
        total_invoices: invRow.total_invoices,
        paid_invoices: invRow.paid_invoices,
        pending_invoices: invRow.pending_invoices,
        overdue_invoices: invRow.overdue_invoices,
        overdue_amount: money(ctx, invRow.overdue_amount),
        invoiced_this_month: money(ctx, invRow.invoiced_this_month),
        total_deliveries: delRow.total_deliveries,
        delivered_count: delRow.delivered_count,
        delivery_success_rate: `${successRate}%`,
      };
    },
  },

  // ==========================================
  // WRITE TOOLS
  // ==========================================

  create_invoice: {
    name: 'create_invoice',
    description:
      'Create a new official invoice with line items. Calculates totals and assigns a sequential invoice number.',
    parameters: {
      type: 'object',
      required: ['customer_name', 'items'],
      properties: {
        customer_name: {
          type: 'string',
          description: 'Client or hospital name (e.g. Nairobi Hospital, Dr. Kamau)',
        },
        customer_phone: {
          type: 'string',
          description: 'Optional contact telephone number',
        },
        customer_email: {
          type: 'string',
          description: 'Optional client billing email',
        },
        customer_pin: {
          type: 'string',
          description: 'Optional KRA PIN number of the customer',
        },
        items: {
          type: 'array',
          description: 'List of line items to include on the invoice',
          items: {
            type: 'object',
            required: ['product_name', 'quantity', 'unit_price'],
            properties: {
              product_name: { type: 'string', description: 'Item name from catalog or custom item' },
              description: { type: 'string', description: 'Optional specification or details' },
              quantity: { type: 'number', description: 'Quantity (must be > 0)' },
              unit_price: { type: 'number', description: 'Price per unit in KES' },
            },
          },
        },
        tax: {
          type: 'number',
          description: 'Optional tax amount in KES (default 0)',
        },
        notes: {
          type: 'string',
          description: 'Payment terms or delivery instructions',
        },
        due_date: {
          type: 'string',
          description: 'Due date in YYYY-MM-DD format (default: 30 days from now)',
        },
      },
    },
    writes: true,
    table: 'invoices',
    describe: (args: any) => {
      const count = Array.isArray(args.items) ? args.items.length : 0;
      let total = 0;
      if (Array.isArray(args.items)) {
        total = args.items.reduce(
          (sum: number, it: any) => sum + (Number(it.quantity) || 1) * (Number(it.unit_price) || 0),
          0
        );
      }
      const tax = Number(args.tax) || 0;
      const lines = Array.isArray(args.items)
        ? args.items
            .slice(0, 8)
            .map((it: any) => `${Number(it.quantity) || 1} × ${it.product_name} @ KES ${Number(it.unit_price || 0).toLocaleString('en-US')}`)
            .join('; ')
        : '';
      const more = count > 8 ? `; +${count - 8} more` : '';
      return `Create invoice for "${args.customer_name}" with ${count} item(s) totaling KES ${(total + tax).toLocaleString('en-US', { minimumFractionDigits: 2 })}${tax ? ` (incl. KES ${tax.toLocaleString('en-US')} tax)` : ''}. Items: ${lines}${more}.`;
    },
    run: async (ctx: ToolContext, args: any) => {
      const client = await getClient();
      try {
        const {
          customer_name,
          customer_phone,
          customer_email,
          customer_pin,
          items = [],
          tax = 0,
          notes,
          due_date,
        } = args;

        if (!customer_name || !Array.isArray(items) || items.length === 0) {
          throw new Error('Customer name and at least one item are required.');
        }
        for (const item of items) {
          if (!item?.product_name) throw new Error('Every line item needs a product_name.');
          if (!(Number(item.quantity) > 0)) throw new Error(`Quantity for "${item.product_name}" must be greater than 0.`);
          if (!(Number(item.unit_price) >= 0)) throw new Error(`Unit price for "${item.product_name}" is invalid.`);
        }
        if (due_date && !/^\d{4}-\d{2}-\d{2}$/.test(String(due_date))) {
          throw new Error('due_date must be in YYYY-MM-DD format.');
        }

        let subtotal = 0;
        const computedItems: any[] = [];
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

        const invoiceNumber = await nextDocumentNumber(client, 'invoices', 'INV', ctx.businessId);
        const verificationToken = generateVerificationToken();
        const resolvedDueDate =
          due_date ||
          new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

        const invInsert = await client.query(
          `INSERT INTO invoices (
            business_id, invoice_number, customer_name, customer_phone, customer_email,
            customer_pin, status, subtotal, tax, total_amount, verification_token,
            issued_date, due_date, notes
          ) VALUES ($1, $2, $3, $4, $5, $6, 'ISSUED', $7, $8, $9, $10, CURRENT_DATE, $11, $12)
          RETURNING *;`,
          [
            ctx.businessId,
            invoiceNumber,
            customer_name,
            customer_phone || null,
            customer_email || null,
            customer_pin || null,
            subtotal,
            computedTax,
            totalAmount,
            verificationToken,
            resolvedDueDate,
            notes || 'Payment due within 30 days. Thank you for your business!',
          ]
        );

        const createdInvoice = invInsert.rows[0];

        for (const it of computedItems) {
          await client.query(
            `INSERT INTO invoice_items (invoice_id, product_name, description, quantity, unit_price, total_price)
             VALUES ($1, $2, $3, $4, $5, $6);`,
            [createdInvoice.id, it.product_name, it.description, it.quantity, it.unit_price, it.total_price]
          );
        }

        await client.query('COMMIT');

        return {
          success: true,
          action: 'created_invoice',
          entity: 'invoices',
          id: createdInvoice.id,
          invoice_number: createdInvoice.invoice_number,
          customer_name: createdInvoice.customer_name,
          total_amount: `${ctx.currency} ${Number(createdInvoice.total_amount).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
          item_count: computedItems.length,
          verification_token: createdInvoice.verification_token,
        };
      } catch (err: any) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    },
  },

  save_product: {
    name: 'save_product',
    description:
      'Add a new medical/surgical product to the catalog or update an existing item price and code.',
    parameters: {
      type: 'object',
      required: ['name', 'unit_price'],
      properties: {
        name: {
          type: 'string',
          description: 'Product name (e.g. "Straight T-plate 20x12 holes", "4.5 cortical screws size 32")',
        },
        unit_price: {
          type: 'number',
          description: 'Unit price in KES',
        },
        item_code: {
          type: 'string',
          description: 'Optional catalog item SKU/code (e.g. KE2BLXAVX00001)',
        },
        tax_type: {
          type: 'string',
          description: 'Tax category (default: "D-Non VAT")',
        },
      },
    },
    writes: true,
    table: 'products',
    describe: (args: any) =>
      `Save product "${args.name}" at KES ${Number(args.unit_price || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })} in the catalog.`,
    run: async (ctx: ToolContext, args: any) => {
      const { name, unit_price, item_code, tax_type = 'D-Non VAT' } = args;
      if (!name || !(Number(unit_price) > 0)) {
        throw new Error('Product name and a positive unit price are required.');
      }

      const prev = await query('SELECT * FROM products WHERE business_id = $1 AND name = $2', [
        ctx.businessId,
        String(name).trim(),
      ]);
      const previous = prev.rows[0];

      const res = await query(
        `INSERT INTO products (business_id, item_code, name, unit_price, tax_type)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (business_id, name)
         DO UPDATE SET unit_price = EXCLUDED.unit_price, item_code = COALESCE(EXCLUDED.item_code, products.item_code)
         RETURNING *;`,
        [ctx.businessId, item_code || null, name.trim(), parseFloat(unit_price), tax_type]
      );

      const product = res.rows[0];
      return {
        success: true,
        action: previous ? 'updated_product' : 'created_product',
        entity: 'products',
        previous: previous
          ? { unit_price: Number(previous.unit_price), item_code: previous.item_code, tax_type: previous.tax_type }
          : null,
        id: product.id,
        name: product.name,
        item_code: product.item_code,
        unit_price: `${ctx.currency} ${Number(product.unit_price).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
        tax_type: product.tax_type,
      };
    },
  },

  create_quotation: {
    name: 'create_quotation',
    description:
      'Create a price quotation for a customer (not an invoice; nothing is owed yet). Assigns the next quote number and totals the items.',
    parameters: {
      type: 'object',
      required: ['customer_name', 'items'],
      properties: {
        customer_name: { type: 'string', description: 'Client or hospital name' },
        customer_phone: { type: 'string', description: 'Optional contact phone' },
        customer_email: { type: 'string', description: 'Optional contact email' },
        items: {
          type: 'array',
          description: 'Line items to quote',
          items: {
            type: 'object',
            required: ['product_name', 'quantity', 'unit_price'],
            properties: {
              product_name: { type: 'string', description: 'Item description, ideally the catalog name' },
              description: { type: 'string', description: 'Optional specification or code' },
              quantity: { type: 'number', description: 'Quantity (must be > 0)' },
              unit_price: { type: 'number', description: 'Price per unit in KES' },
            },
          },
        },
        tax: { type: 'number', description: 'Optional tax amount in KES (default 0)' },
        due_date: {
          type: 'string',
          description: 'Quote due / valid-until date in YYYY-MM-DD (default: 14 days from today)',
        },
        terms: { type: 'string', description: 'Optional terms; leave empty for the standard Selisco terms' },
      },
    },
    writes: true,
    table: 'quotations',
    describe: (args: any) => {
      const items = Array.isArray(args.items) ? args.items : [];
      const total =
        items.reduce((sum: number, it: any) => sum + (Number(it.quantity) || 1) * (Number(it.unit_price) || 0), 0) +
        (Number(args.tax) || 0);
      const lines = items
        .slice(0, 8)
        .map((it: any) => `${Number(it.quantity) || 1} × ${it.product_name} @ KES ${Number(it.unit_price || 0).toLocaleString('en-US')}`)
        .join('; ');
      const more = items.length > 8 ? `; +${items.length - 8} more` : '';
      return `Create quotation for "${args.customer_name}" with ${items.length} item(s) totaling KES ${total.toLocaleString('en-US', { minimumFractionDigits: 2 })}. Items: ${lines}${more}.`;
    },
    run: async (ctx: ToolContext, args: any) => {
      await ensureQuotationTables();
      const client = await getClient();
      try {
        if (args.due_date && !/^\d{4}-\d{2}-\d{2}$/.test(String(args.due_date))) {
          throw new Error('due_date must be in YYYY-MM-DD format.');
        }
        await client.query('BEGIN');
        const q = await insertQuotation(client, ctx.businessId, {
          ...args,
          terms: args.terms || undefined,
        });
        await client.query('COMMIT');
        return {
          success: true,
          action: 'created_quotation',
          entity: 'quotations',
          id: q.id,
          quote_number: q.quote_number,
          customer_name: q.customer_name,
          total_amount: money(ctx, q.total_amount),
          item_count: q.items.length,
          due_date: args.due_date || null,
        };
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    },
  },

  update_quotation_status: {
    name: 'update_quotation_status',
    description: 'Record the customer\'s response to a quotation: mark it SENT, ACCEPTED, DECLINED or back to DRAFT.',
    parameters: {
      type: 'object',
      required: ['status'],
      properties: {
        quote_number: { type: 'string', description: 'Quotation number (e.g. QT-2026-0001)' },
        quotation_id: { type: 'string', description: 'UUID of the quotation' },
        status: { type: 'string', enum: ['DRAFT', 'SENT', 'ACCEPTED', 'DECLINED'], description: 'New status' },
      },
    },
    writes: true,
    table: 'quotations',
    describe: (args: any) =>
      `Mark quotation ${args.quote_number || args.quotation_id || 'selected'} as ${String(args.status).toUpperCase()}.`,
    run: async (ctx: ToolContext, args: any) => {
      const status = normStatus(args.status, ['DRAFT', 'SENT', 'ACCEPTED', 'DECLINED']);
      const q = await findQuotation(query, ctx, args.quotation_id, args.quote_number);
      if (!q) throw new Error('Quotation not found.');
      if (q.status === 'INVOICED') {
        throw new Error(`Quotation ${q.quote_number} has already been converted to an invoice.`);
      }
      await query('UPDATE quotations SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2', [status, q.id]);
      return {
        success: true,
        action: 'updated_quotation_status',
        entity: 'quotations',
        id: q.id,
        quote_number: q.quote_number,
        customer_name: q.customer_name,
        previous_status: q.status,
        new_status: status,
      };
    },
  },

  convert_quotation_to_invoice: {
    name: 'convert_quotation_to_invoice',
    description:
      'Turn an accepted quotation into an issued invoice with the same customer and items, and mark the quotation INVOICED.',
    parameters: {
      type: 'object',
      properties: {
        quote_number: { type: 'string', description: 'Quotation number (e.g. QT-2026-0001)' },
        quotation_id: { type: 'string', description: 'UUID of the quotation' },
        due_date: { type: 'string', description: 'Invoice due date YYYY-MM-DD (default: 30 days from today)' },
      },
    },
    writes: true,
    alwaysConfirm: true,
    table: 'invoices',
    describe: (args: any) =>
      `Create an invoice from quotation ${args.quote_number || args.quotation_id || 'selected'}.`,
    run: async (ctx: ToolContext, args: any) => {
      const client = await getClient();
      try {
        await client.query('BEGIN');
        const q = await findQuotation(
          (t, p) => client.query(t, p),
          ctx,
          args.quotation_id,
          args.quote_number
        );
        if (!q) throw new Error('Quotation not found.');
        const { invoice, previous_status, item_count } = await convertQuotationToInvoice(client, q, {
          due_date: args.due_date,
        });
        await client.query('COMMIT');
        return {
          success: true,
          action: 'converted_quotation',
          entity: 'invoices',
          id: invoice.id,
          invoice_number: invoice.invoice_number,
          quotation_id: q.id,
          quote_number: q.quote_number,
          previous_quote_status: previous_status,
          customer_name: invoice.customer_name,
          total_amount: money(ctx, invoice.total_amount),
          item_count,
        };
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    },
  },

  convert_invoice_to_delivery_note: {
    name: 'convert_invoice_to_delivery_note',
    description:
      'Convert an existing invoice into a dispatched delivery note. Copies all invoice items for physical delivery tracking.',
    parameters: {
      type: 'object',
      properties: {
        invoice_number: {
          type: 'string',
          description: 'Invoice number to convert (e.g. INV-2026-0001)',
        },
        invoice_id: {
          type: 'string',
          description: 'UUID of the invoice',
        },
        recipient_name: {
          type: 'string',
          description: 'Name of the recipient or hospital receiver',
        },
        notes: {
          type: 'string',
          description: 'Dispatch or delivery notes',
        },
      },
    },
    writes: true,
    alwaysConfirm: true,
    table: 'delivery_notes',
    describe: (args: any) =>
      `Generate a delivery note from invoice ${args.invoice_number || args.invoice_id || 'selected'} for recipient "${args.recipient_name || 'Customer'}".`,
    run: async (ctx: ToolContext, args: any) => {
      const client = await getClient();
      try {
        const invoice = await findInvoice(
          (t, p) => client.query(t, p),
          ctx,
          args.invoice_id,
          args.invoice_number
        );
        if (!invoice) {
          throw new Error('Invoice not found.');
        }
        if (invoice.status === 'CANCELLED') {
          throw new Error(`Invoice ${invoice.invoice_number} is CANCELLED and cannot be delivered.`);
        }

        await client.query('BEGIN');

        const noteNumber = await nextDocumentNumber(client, 'delivery_notes', 'DN', ctx.businessId);

        const dnInsert = await client.query(
          `INSERT INTO delivery_notes (
            invoice_id, business_id, note_number, status, recipient_name, notes, dispatched_at, subtotal, tax, total_amount
          ) VALUES ($1, $2, $3, 'PENDING', $4, $5, CURRENT_TIMESTAMP, $6, $7, $8)
          RETURNING *;`,
          [
            invoice.id,
            ctx.businessId,
            noteNumber,
            args.recipient_name || invoice.customer_name,
            args.notes || 'Items packed and prepared for delivery.',
            invoice.subtotal || 0,
            invoice.tax || 0,
            invoice.total_amount || 0,
          ]
        );

        const deliveryNote = dnInsert.rows[0];

        // Copy invoice items into delivery_note_items with prices
        const itemsRes = await client.query(
          'SELECT id, product_name, quantity, unit_price, total_price FROM invoice_items WHERE invoice_id = $1',
          [invoice.id]
        );

        for (const it of itemsRes.rows) {
          await client.query(
            `INSERT INTO delivery_note_items (
              delivery_note_id, invoice_item_id, product_name, ordered_quantity, delivered_quantity, unit_price, total_price
            ) VALUES ($1, $2, $3, $4, 0, $5, $6);`,
            [deliveryNote.id, it.id, it.product_name, it.quantity, it.unit_price || 0, it.total_price || 0]
          );
        }

        await client.query('COMMIT');

        return {
          success: true,
          action: 'converted_delivery_note',
          entity: 'delivery_notes',
          id: deliveryNote.id,
          note_number: deliveryNote.note_number,
          invoice_number: invoice.invoice_number,
          recipient_name: deliveryNote.recipient_name,
          total_amount: Number(deliveryNote.total_amount || invoice.total_amount || 0),
          formatted_amount: `${ctx.currency} ${Number(deliveryNote.total_amount || invoice.total_amount || 0).toLocaleString('en-US', { minimumFractionDigits: 2 })}`,
          items_count: itemsRes.rows.length,
        };
      } catch (err: any) {
        await client.query('ROLLBACK');
        throw err;
      } finally {
        client.release();
      }
    },
  },

  update_invoice_status: {
    name: 'update_invoice_status',
    description: 'Update the payment or issuance status of an invoice (e.g. mark as PAID or CANCELLED).',
    parameters: {
      type: 'object',
      required: ['status'],
      properties: {
        invoice_number: {
          type: 'string',
          description: 'Invoice number (e.g. INV-2026-0001)',
        },
        invoice_id: {
          type: 'string',
          description: 'UUID of the invoice',
        },
        status: {
          type: 'string',
          enum: INVOICE_STATUSES,
          description: 'New status',
        },
      },
    },
    writes: true,
    table: 'invoices',
    describe: (args: any) =>
      `Update invoice ${args.invoice_number || args.invoice_id || 'selected'} status to ${args.status}.`,
    run: async (ctx: ToolContext, args: any) => {
      const status = normStatus(args.status, INVOICE_STATUSES);
      const invoice = await findInvoice(query, ctx, args.invoice_id, args.invoice_number);
      if (!invoice) {
        throw new Error('Invoice not found.');
      }

      const res = await query(
        'UPDATE invoices SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND business_id = $3 RETURNING *',
        [status, invoice.id, ctx.businessId]
      );
      const updated = res.rows[0];
      return {
        success: true,
        action: 'updated_invoice_status',
        entity: 'invoices',
        id: updated.id,
        invoice_number: updated.invoice_number,
        customer_name: updated.customer_name,
        total_amount: money(ctx, updated.total_amount),
        previous_status: invoice.status,
        new_status: updated.status,
      };
    },
  },

  update_delivery_status: {
    name: 'update_delivery_status',
    description: 'Update tracking status of a delivery note (e.g. mark DELIVERED or IN_TRANSIT).',
    parameters: {
      type: 'object',
      required: ['status'],
      properties: {
        note_number: {
          type: 'string',
          description: 'Delivery note number (e.g. DN-2026-0001)',
        },
        delivery_note_id: {
          type: 'string',
          description: 'UUID of the delivery note',
        },
        status: {
          type: 'string',
          enum: DELIVERY_STATUSES,
          description: 'New status',
        },
        recipient_name: {
          type: 'string',
          description: 'Optional recipient who received the delivery',
        },
      },
    },
    writes: true,
    table: 'delivery_notes',
    describe: (args: any) =>
      `Mark delivery note ${args.note_number || args.delivery_note_id || 'selected'} as ${args.status}.`,
    run: async (ctx: ToolContext, args: any) => {
      const status = normStatus(args.status, DELIVERY_STATUSES);
      const dn = await findDeliveryNote(query, ctx, args.delivery_note_id, args.note_number);
      if (!dn) {
        throw new Error('Delivery note not found.');
      }

      const deliveredAt = status === 'DELIVERED' ? new Date().toISOString() : null;
      const res = await query(
        `UPDATE delivery_notes
         SET status = $1, delivered_at = COALESCE($2, delivered_at),
             recipient_name = COALESCE($3, recipient_name), updated_at = CURRENT_TIMESTAMP
         WHERE id = $4 AND business_id = $5 RETURNING *`,
        [status, deliveredAt, args.recipient_name || null, dn.id, ctx.businessId]
      );

      return {
        success: true,
        action: 'updated_delivery_status',
        entity: 'delivery_notes',
        id: res.rows[0].id,
        note_number: res.rows[0].note_number,
        recipient_name: res.rows[0].recipient_name,
        new_status: res.rows[0].status,
        previous: {
          status: dn.status,
          delivered_at: dn.delivered_at,
          recipient_name: dn.recipient_name,
        },
      };
    },
  },

  delete_invoice: {
    name: 'delete_invoice',
    description:
      'Permanently delete an invoice together with its line items and any delivery notes created from it. Prefer update_invoice_status to CANCELLED unless the user explicitly asks to delete.',
    parameters: {
      type: 'object',
      properties: {
        invoice_number: {
          type: 'string',
          description: 'Invoice number (e.g. INV-2026-0001)',
        },
        invoice_id: {
          type: 'string',
          description: 'UUID of the invoice',
        },
      },
    },
    writes: true,
    alwaysConfirm: true,
    table: 'invoices',
    describe: (args: any) =>
      `Permanently delete invoice ${args.invoice_number || args.invoice_id || 'selected'}.`,
    run: async (ctx: ToolContext, args: any) => {
      const invoice = await findInvoice(query, ctx, args.invoice_id, args.invoice_number);
      if (!invoice) {
        throw new Error('Invoice not found or already deleted.');
      }

      // Snapshot everything the cascade removes so the action can be undone.
      const snapshot = await query(
        `SELECT
           (SELECT row_to_json(i) FROM invoices i WHERE i.id = $1) AS invoice,
           (SELECT COALESCE(json_agg(it), '[]') FROM invoice_items it WHERE it.invoice_id = $1) AS invoice_items,
           (SELECT COALESCE(json_agg(dn), '[]') FROM delivery_notes dn WHERE dn.invoice_id = $1) AS delivery_notes,
           (SELECT COALESCE(json_agg(dni), '[]') FROM delivery_note_items dni
              JOIN delivery_notes dn ON dn.id = dni.delivery_note_id WHERE dn.invoice_id = $1) AS delivery_note_items`,
        [invoice.id]
      );

      await query('DELETE FROM invoices WHERE id = $1 AND business_id = $2', [invoice.id, ctx.businessId]);

      return {
        success: true,
        action: 'deleted_invoice',
        entity: 'invoices',
        id: invoice.id,
        invoice_number: invoice.invoice_number,
        customer_name: invoice.customer_name,
        snapshot: snapshot.rows[0],
      };
    },
  },
};
