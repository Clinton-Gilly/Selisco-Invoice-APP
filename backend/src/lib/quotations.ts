import { query } from '@/lib/db';
import { nextDocumentNumber } from '@/lib/numbering';
import { generateVerificationToken } from '@/utils/crypto';

type Db = { query: (text: string, params?: any[]) => Promise<{ rows: any[] }> };

export const QUOTATION_STATUSES = ['DRAFT', 'SENT', 'ACCEPTED', 'DECLINED', 'INVOICED'] as const;

export const DEFAULT_QUOTATION_TERMS = 'Payment is due within 14 days.\nPlease make cheques payable to SELISCO LTD.';

let tablesReady = false;

/** Creates the quotation tables on first use (mirrors scripts/schema_quotations.sql). */
export async function ensureQuotationTables(): Promise<void> {
  if (tablesReady) return;
  await query(`
    CREATE TABLE IF NOT EXISTS quotations (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
      quote_number VARCHAR(50) NOT NULL,
      customer_name VARCHAR(255) NOT NULL,
      customer_phone VARCHAR(50),
      customer_email VARCHAR(255),
      status VARCHAR(20) NOT NULL DEFAULT 'SENT'
        CHECK (status IN ('DRAFT', 'SENT', 'ACCEPTED', 'DECLINED', 'INVOICED')),
      subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
      tax NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
      total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
      quote_date DATE NOT NULL DEFAULT CURRENT_DATE,
      due_date DATE NOT NULL,
      terms TEXT,
      invoice_id UUID REFERENCES invoices(id) ON DELETE SET NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT uq_business_quote_number UNIQUE (business_id, quote_number)
    );

    CREATE TABLE IF NOT EXISTS quotation_items (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      quotation_id UUID NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
      product_name VARCHAR(255) NOT NULL,
      description TEXT,
      quantity NUMERIC(10, 2) NOT NULL CHECK (quantity > 0),
      unit_price NUMERIC(12, 2) NOT NULL CHECK (unit_price >= 0),
      total_price NUMERIC(12, 2) NOT NULL CHECK (total_price >= 0),
      created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE INDEX IF NOT EXISTS idx_quotations_business ON quotations(business_id, created_at DESC);
    CREATE INDEX IF NOT EXISTS idx_quotation_items_quote ON quotation_items(quotation_id);
  `);
  tablesReady = true;
}

export async function resolveBusinessId(db: Db, provided?: string | null): Promise<string> {
  if (provided) return provided;
  const res = await db.query('SELECT id FROM businesses ORDER BY created_at ASC LIMIT 1');
  if (res.rows.length === 0) throw new Error('No business profile found. Please create a business first.');
  return res.rows[0].id;
}

export interface QuotationInput {
  customer_name: string;
  customer_phone?: string;
  customer_email?: string;
  items: { product_name: string; description?: string; quantity: any; unit_price: any }[];
  tax?: any;
  quote_date?: string;
  due_date?: string;
  terms?: string;
  status?: string;
}

/** Inserts a quotation and its items. Caller owns the transaction. */
export async function insertQuotation(db: Db, businessId: string, input: QuotationInput) {
  const { customer_name, items } = input;
  if (!customer_name || !String(customer_name).trim()) throw new Error('Customer name is required.');
  if (!Array.isArray(items) || items.length === 0) throw new Error('At least one item is required.');

  let subtotal = 0;
  const computed = items.map((item) => {
    if (!item?.product_name || !String(item.product_name).trim()) {
      throw new Error('Every item needs a description.');
    }
    const quantity = parseFloat(item.quantity);
    const unitPrice = parseFloat(item.unit_price);
    if (!(quantity > 0)) throw new Error(`Quantity for "${item.product_name}" must be greater than 0.`);
    if (!(unitPrice >= 0)) throw new Error(`Unit price for "${item.product_name}" is invalid.`);
    const total = parseFloat((quantity * unitPrice).toFixed(2));
    subtotal += total;
    return {
      product_name: String(item.product_name).trim(),
      description: item.description ? String(item.description).trim() || null : null,
      quantity,
      unit_price: unitPrice,
      total_price: total,
    };
  });

  subtotal = parseFloat(subtotal.toFixed(2));
  const tax = parseFloat((parseFloat(input.tax ?? 0) || 0).toFixed(2));
  const total = parseFloat((subtotal + tax).toFixed(2));
  const status = String(input.status || 'SENT').toUpperCase();
  if (!(QUOTATION_STATUSES as readonly string[]).includes(status)) {
    throw new Error(`Invalid status "${input.status}".`);
  }

  const quoteNumber = await nextDocumentNumber(db, 'quotations', 'QT', businessId);
  const quoteDate = input.quote_date || new Date().toISOString().split('T')[0];
  const dueDate =
    input.due_date || new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

  const qRes = await db.query(
    `INSERT INTO quotations (
       business_id, quote_number, customer_name, customer_phone, customer_email,
       status, subtotal, tax, total_amount, quote_date, due_date, terms
     ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING *, to_char(quote_date, 'YYYY-MM-DD') AS quote_date, to_char(due_date, 'YYYY-MM-DD') AS due_date`,
    [
      businessId,
      quoteNumber,
      String(customer_name).trim(),
      input.customer_phone || null,
      input.customer_email || null,
      status,
      subtotal,
      tax,
      total,
      quoteDate,
      dueDate,
      input.terms ?? DEFAULT_QUOTATION_TERMS,
    ]
  );
  const quotation = qRes.rows[0];

  const savedItems: any[] = [];
  for (const it of computed) {
    const r = await db.query(
      `INSERT INTO quotation_items (quotation_id, product_name, description, quantity, unit_price, total_price)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [quotation.id, it.product_name, it.description, it.quantity, it.unit_price, it.total_price]
    );
    savedItems.push(r.rows[0]);
  }

  return { ...quotation, items: savedItems };
}

/**
 * Turns a quotation into an issued invoice with the same customer and items,
 * and marks the quotation INVOICED. Caller owns the transaction.
 */
export async function convertQuotationToInvoice(db: Db, quotation: any, options: { due_date?: string; notes?: string } = {}) {
  if (quotation.status === 'INVOICED' && quotation.invoice_id) {
    throw new Error(`Quotation ${quotation.quote_number} has already been converted to an invoice.`);
  }
  if (quotation.status === 'DECLINED') {
    throw new Error(`Quotation ${quotation.quote_number} was declined by the customer.`);
  }

  const itemsRes = await db.query(
    'SELECT product_name, description, quantity, unit_price, total_price FROM quotation_items WHERE quotation_id = $1 ORDER BY created_at ASC',
    [quotation.id]
  );
  if (itemsRes.rows.length === 0) throw new Error('This quotation has no items.');

  const invoiceNumber = await nextDocumentNumber(db, 'invoices', 'INV', quotation.business_id);
  const dueDate =
    options.due_date || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];

  const invRes = await db.query(
    `INSERT INTO invoices (
       business_id, invoice_number, customer_name, customer_phone, customer_email,
       status, subtotal, tax, total_amount, verification_token, issued_date, due_date, notes
     ) VALUES ($1, $2, $3, $4, $5, 'ISSUED', $6, $7, $8, $9, CURRENT_DATE, $10, $11)
     RETURNING *`,
    [
      quotation.business_id,
      invoiceNumber,
      quotation.customer_name,
      quotation.customer_phone,
      quotation.customer_email,
      quotation.subtotal,
      quotation.tax,
      quotation.total_amount,
      generateVerificationToken(),
      dueDate,
      options.notes || `Ref: Quotation ${quotation.quote_number}. Account are due on demand.`,
    ]
  );
  const invoice = invRes.rows[0];

  for (const it of itemsRes.rows) {
    await db.query(
      `INSERT INTO invoice_items (invoice_id, product_name, description, quantity, unit_price, total_price)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [invoice.id, it.product_name, it.description, it.quantity, it.unit_price, it.total_price]
    );
  }

  await db.query(
    `UPDATE quotations SET status = 'INVOICED', invoice_id = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2`,
    [invoice.id, quotation.id]
  );

  return { invoice, previous_status: quotation.status, item_count: itemsRes.rows.length };
}
