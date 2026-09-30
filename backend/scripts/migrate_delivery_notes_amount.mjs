import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config({ path: './.env.local' });

const connectionString = process.env.DATABASE_URL;
if (!connectionString) {
  console.error('DATABASE_URL is not set');
  process.exit(1);
}

const pool = new pg.Pool({
  connectionString,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  const client = await pool.connect();
  try {
    console.log('Running migration: Add amount columns to delivery_notes and delivery_note_items...');
    await client.query('BEGIN');

    // 1. Add columns to delivery_notes
    await client.query(`
      ALTER TABLE delivery_notes 
        ADD COLUMN IF NOT EXISTS subtotal NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
        ADD COLUMN IF NOT EXISTS tax NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
        ADD COLUMN IF NOT EXISTS total_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
    `);

    // 2. Add columns to delivery_note_items
    await client.query(`
      ALTER TABLE delivery_note_items 
        ADD COLUMN IF NOT EXISTS unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
        ADD COLUMN IF NOT EXISTS total_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00;
    `);

    // 3. Backfill existing delivery_notes from invoices
    const updateNotesRes = await client.query(`
      UPDATE delivery_notes dn
      SET 
        subtotal = i.subtotal,
        tax = i.tax,
        total_amount = i.total_amount
      FROM invoices i
      WHERE dn.invoice_id = i.id;
    `);
    console.log(`Backfilled ${updateNotesRes.rowCount} delivery_notes with invoice amounts.`);

    // 4. Backfill existing delivery_note_items from invoice_items
    const updateItemsRes = await client.query(`
      UPDATE delivery_note_items dni
      SET 
        unit_price = COALESCE(ii.unit_price, 0.00),
        total_price = COALESCE(ii.unit_price * dni.ordered_quantity, 0.00)
      FROM invoice_items ii
      WHERE dni.invoice_item_id = ii.id;
    `);
    console.log(`Backfilled ${updateItemsRes.rowCount} delivery_note_items with item prices.`);

    await client.query('COMMIT');
    console.log('Migration completed successfully!');
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
