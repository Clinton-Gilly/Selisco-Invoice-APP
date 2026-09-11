import { query, getClient } from '@/lib/db';
import { generateVerificationToken } from '@/utils/crypto';
import { ToolContext, ToolDef } from './types';

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
          description: 'Filter by status: ALL, DRAFT, ISSUED, PAID, OVERDUE, CANCELLED',
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

      if (status && status !== 'ALL') {
        conditions.push(`i.status = $${pIdx++}`);
        values.push(status);
      }

      if (search && search.trim()) {
        conditions.push(
          `(i.invoice_number ILIKE $${pIdx} OR i.customer_name ILIKE $${pIdx} OR i.customer_phone ILIKE $${pIdx})`
        );
        values.push(`%${search.trim()}%`);
        pIdx++;
      }

      const cappedLimit = Math.min(Math.max(1, limit), 20);
      values.push(cappedLimit);

      const sql = `
        SELECT 
          i.id, i.invoice_number, i.customer_name, i.customer_phone,
          i.status, i.total_amount, i.issued_date, i.due_date,
          COUNT(it.id)::int as item_count
        FROM invoices i
        LEFT JOIN invoice_items it ON i.id = it.invoice_id
        WHERE ${conditions.join(' AND ')}
        GROUP BY i.id
        ORDER BY i.created_at DESC
        LIMIT $${pIdx};
      `;

      const res = await query(sql, values);
      return {
        total_found: res.rows.length,
        invoices: res.rows.map((row) => ({
          ...row,
          total_amount_formatted: `${ctx.currency} ${Number(row.total_amount).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
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
      let invRes;
      if (args.id) {
        invRes = await query('SELECT * FROM invoices WHERE id = $1 AND business_id = $2', [
          args.id,
          ctx.businessId,
        ]);
      } else if (args.invoice_number) {
        invRes = await query(
          'SELECT * FROM invoices WHERE invoice_number ILIKE $1 AND business_id = $2',
          [args.invoice_number.trim(), ctx.businessId]
        );
      } else {
        throw new Error('Either id or invoice_number must be provided');
      }

      if (invRes.rows.length === 0) {
        return { found: false, message: 'Invoice not found.' };
      }

      const invoice = invRes.rows[0];
      const itemsRes = await query(
        'SELECT product_name, description, quantity, unit_price, total_price FROM invoice_items WHERE invoice_id = $1 ORDER BY created_at ASC',
        [invoice.id]
      );

      const dnRes = await query(
        'SELECT id, note_number, status FROM delivery_notes WHERE invoice_id = $1',
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
          formatted_total: `${ctx.currency} ${Number(invoice.total_amount).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
          issued_date: invoice.issued_date,
          due_date: invoice.due_date,
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
          description: 'Filter by status: ALL, PENDING, IN_TRANSIT, DELIVERED, REJECTED',
        },
        search: {
          type: 'string',
          description: 'Search by note number or recipient name',
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

      if (status && status !== 'ALL') {
        conditions.push(`dn.status = $${pIdx++}`);
        values.push(status);
      }

      if (search && search.trim()) {
        conditions.push(`(dn.note_number ILIKE $${pIdx} OR dn.recipient_name ILIKE $${pIdx})`);
        values.push(`%${search.trim()}%`);
        pIdx++;
      }

      const capped = Math.min(Math.max(1, limit), 20);
      values.push(capped);

      const sql = `
        SELECT 
          dn.id, dn.note_number, dn.status, dn.recipient_name,
          dn.dispatched_at, dn.delivered_at, i.invoice_number, i.customer_name
        FROM delivery_notes dn
        JOIN invoices i ON dn.invoice_id = i.id
        WHERE ${conditions.join(' AND ')}
        ORDER BY dn.created_at DESC
        LIMIT $${pIdx};
      `;

      const res = await query(sql, values);
      return {
        count: res.rows.length,
        delivery_notes: res.rows,
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
          COUNT(CASE WHEN status IN ('ISSUED', 'OVERDUE') THEN 1 END)::int as pending_invoices
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
      return `Create invoice for "${args.customer_name}" with ${count} item(s) totaling KES ${total.toLocaleString(undefined, { minimumFractionDigits: 2 })}.`;
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

        if (!customer_name || items.length === 0) {
          throw new Error('Customer name and at least one item are required.');
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

        // Sequence number
        const countRes = await client.query(
          'SELECT COUNT(*)::int as total FROM invoices WHERE business_id = $1',
          [ctx.businessId]
        );
        const invoiceSeq = (countRes.rows[0].total + 1).toString().padStart(4, '0');
        const currentYear = new Date().getFullYear();
        const invoiceNumber = `INV-${currentYear}-${invoiceSeq}`;
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
      if (!name || !unit_price) {
        throw new Error('Product name and unit price are required.');
      }

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
        action: 'saved_product',
        entity: 'products',
        id: product.id,
        name: product.name,
        item_code: product.item_code,
        unit_price: `${ctx.currency} ${Number(product.unit_price).toLocaleString(undefined, { minimumFractionDigits: 2 })}`,
        tax_type: product.tax_type,
      };
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
        let invRes;
        if (args.invoice_id) {
          invRes = await client.query('SELECT * FROM invoices WHERE id = $1 AND business_id = $2', [
            args.invoice_id,
            ctx.businessId,
          ]);
        } else if (args.invoice_number) {
          invRes = await client.query(
            'SELECT * FROM invoices WHERE invoice_number ILIKE $1 AND business_id = $2',
            [args.invoice_number.trim(), ctx.businessId]
          );
        } else {
          throw new Error('Either invoice_id or invoice_number is required.');
        }

        if (invRes.rows.length === 0) {
          throw new Error('Invoice not found.');
        }

        const invoice = invRes.rows[0];

        await client.query('BEGIN');

        // Sequence number
        const countRes = await client.query(
          'SELECT COUNT(*)::int as total FROM delivery_notes WHERE business_id = $1',
          [ctx.businessId]
        );
        const seq = (countRes.rows[0].total + 1).toString().padStart(4, '0');
        const currentYear = new Date().getFullYear();
        const noteNumber = `DN-${currentYear}-${seq}`;

        const dnInsert = await client.query(
          `INSERT INTO delivery_notes (
            invoice_id, business_id, note_number, status, recipient_name, notes, dispatched_at
          ) VALUES ($1, $2, $3, 'PENDING', $4, $5, CURRENT_TIMESTAMP)
          RETURNING *;`,
          [
            invoice.id,
            ctx.businessId,
            noteNumber,
            args.recipient_name || invoice.customer_name,
            args.notes || 'Items packed and prepared for delivery.',
          ]
        );

        const deliveryNote = dnInsert.rows[0];

        // Copy invoice items into delivery_note_items
        const itemsRes = await client.query(
          'SELECT id, product_name, quantity FROM invoice_items WHERE invoice_id = $1',
          [invoice.id]
        );

        for (const it of itemsRes.rows) {
          await client.query(
            `INSERT INTO delivery_note_items (
              delivery_note_id, invoice_item_id, product_name, ordered_quantity, delivered_quantity
            ) VALUES ($1, $2, $3, $4, 0);`,
            [deliveryNote.id, it.id, it.product_name, it.quantity]
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
          description: 'New status: DRAFT, ISSUED, PAID, OVERDUE, CANCELLED',
        },
      },
    },
    writes: true,
    table: 'invoices',
    describe: (args: any) =>
      `Update invoice ${args.invoice_number || args.invoice_id || 'selected'} status to ${args.status}.`,
    run: async (ctx: ToolContext, args: any) => {
      const { invoice_id, invoice_number, status } = args;
      const validStatuses = ['DRAFT', 'ISSUED', 'PAID', 'OVERDUE', 'CANCELLED'];
      if (!validStatuses.includes(status)) {
        throw new Error(`Invalid status "${status}". Must be one of: ${validStatuses.join(', ')}`);
      }

      let res;
      if (invoice_id) {
        res = await query(
          'UPDATE invoices SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2 AND business_id = $3 RETURNING *',
          [status, invoice_id, ctx.businessId]
        );
      } else if (invoice_number) {
        res = await query(
          'UPDATE invoices SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE invoice_number ILIKE $2 AND business_id = $3 RETURNING *',
          [status, invoice_number.trim(), ctx.businessId]
        );
      } else {
        throw new Error('Either invoice_id or invoice_number must be provided.');
      }

      if (res.rows.length === 0) {
        throw new Error('Invoice not found.');
      }

      const updated = res.rows[0];
      return {
        success: true,
        action: 'updated_invoice_status',
        entity: 'invoices',
        id: updated.id,
        invoice_number: updated.invoice_number,
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
          description: 'New status: PENDING, IN_TRANSIT, DELIVERED, REJECTED',
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
      const { note_number, delivery_note_id, status, recipient_name } = args;
      const validStatuses = ['PENDING', 'IN_TRANSIT', 'DELIVERED', 'REJECTED'];
      if (!validStatuses.includes(status)) {
        throw new Error(`Invalid status "${status}".`);
      }

      const deliveredAt = status === 'DELIVERED' ? new Date().toISOString() : null;

      let res;
      if (delivery_note_id) {
        res = await query(
          `UPDATE delivery_notes 
           SET status = $1, delivered_at = COALESCE($2, delivered_at),
               recipient_name = COALESCE($3, recipient_name), updated_at = CURRENT_TIMESTAMP
           WHERE id = $4 AND business_id = $5 RETURNING *`,
          [status, deliveredAt, recipient_name || null, delivery_note_id, ctx.businessId]
        );
      } else if (note_number) {
        res = await query(
          `UPDATE delivery_notes 
           SET status = $1, delivered_at = COALESCE($2, delivered_at),
               recipient_name = COALESCE($3, recipient_name), updated_at = CURRENT_TIMESTAMP
           WHERE note_number ILIKE $4 AND business_id = $5 RETURNING *`,
          [status, deliveredAt, recipient_name || null, note_number.trim(), ctx.businessId]
        );
      } else {
        throw new Error('Either delivery_note_id or note_number is required.');
      }

      if (res.rows.length === 0) {
        throw new Error('Delivery note not found.');
      }

      return {
        success: true,
        action: 'updated_delivery_status',
        entity: 'delivery_notes',
        id: res.rows[0].id,
        note_number: res.rows[0].note_number,
        new_status: res.rows[0].status,
      };
    },
  },

  delete_invoice: {
    name: 'delete_invoice',
    description: 'Permanently delete an invoice and associated items.',
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
      const { invoice_id, invoice_number } = args;
      let res;
      if (invoice_id) {
        res = await query(
          'DELETE FROM invoices WHERE id = $1 AND business_id = $2 RETURNING id, invoice_number',
          [invoice_id, ctx.businessId]
        );
      } else if (invoice_number) {
        res = await query(
          'DELETE FROM invoices WHERE invoice_number ILIKE $1 AND business_id = $2 RETURNING id, invoice_number',
          [invoice_number.trim(), ctx.businessId]
        );
      } else {
        throw new Error('Either invoice_id or invoice_number is required.');
      }

      if (res.rows.length === 0) {
        throw new Error('Invoice not found or already deleted.');
      }

      return {
        success: true,
        action: 'deleted_invoice',
        entity: 'invoices',
        id: res.rows[0].id,
        invoice_number: res.rows[0].invoice_number,
      };
    },
  },
};
