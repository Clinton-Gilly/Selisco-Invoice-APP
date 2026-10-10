type Queryable = { query: (text: string, params?: any[]) => Promise<{ rows: any[] }> };

const SOURCES = {
  invoices: { table: 'invoices', column: 'invoice_number' },
  delivery_notes: { table: 'delivery_notes', column: 'note_number' },
  quotations: { table: 'quotations', column: 'quote_number' },
} as const;

/**
 * Next sequential document number for the current year, e.g. INV-2026-0005.
 * Uses the highest existing number rather than a row count, so deleted
 * documents never cause a duplicate number.
 */
export async function nextDocumentNumber(
  db: Queryable,
  kind: keyof typeof SOURCES,
  prefix: string,
  businessId: string
): Promise<string> {
  const { table, column } = SOURCES[kind];
  const yearPrefix = `${prefix}-${new Date().getFullYear()}-`;
  const res = await db.query(
    `SELECT COALESCE(MAX(CAST(substring(${column} from '([0-9]+)$') AS int)), 0) AS max_seq
     FROM ${table} WHERE business_id = $1 AND ${column} LIKE $2`,
    [businessId, `${yearPrefix}%`]
  );
  const seq = (Number(res.rows[0]?.max_seq) || 0) + 1;
  return `${yearPrefix}${seq.toString().padStart(4, '0')}`;
}
