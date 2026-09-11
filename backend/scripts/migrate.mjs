import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env.local first, fallback to .env
const envLocalPath = path.resolve(__dirname, '../.env.local');
if (fs.existsSync(envLocalPath)) {
  dotenv.config({ path: envLocalPath });
} else {
  dotenv.config();
}

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.error('ERROR: DATABASE_URL environment variable is not set.');
  process.exit(1);
}

console.log('Connecting to Neon PostgreSQL database...');

const pool = new pg.Pool({
  connectionString,
  ssl: {
    rejectUnauthorized: false
  }
});

async function runMigration() {
  const client = await pool.connect();
  try {
    console.log('Applying database schema from schema.sql...');
    const schemaSql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf-8');
    await client.query(schemaSql);
    console.log('Schema applied successfully.');

    // Seed default business if none exists
    const existingBusiness = await client.query('SELECT id, name, currency FROM businesses LIMIT 1');
    let businessId;

    if (existingBusiness.rows.length === 0) {
      console.log('Seeding initial business record...');
      const insertBiz = await client.query(`
        INSERT INTO businesses (name, email, phone, currency, address)
        VALUES (
          'Selisco Logistics & Enterprise Ltd',
          'billing@selisco.com',
          '+1 (555) 234-5678',
          'USD',
          '100 Innovation Boulevard, Suite 400, Tech City, CA 94016'
        )
        RETURNING id, name;
      `);
      businessId = insertBiz.rows[0].id;
      console.log(`Created default business: "${insertBiz.rows[0].name}" [${businessId}]`);
    } else {
      businessId = existingBusiness.rows[0].id;
      console.log(`Found existing business: "${existingBusiness.rows[0].name}" [${businessId}]`);
    }

    // Check if sample invoice exists
    const existingInvoices = await client.query('SELECT id FROM invoices WHERE business_id = $1 LIMIT 1', [businessId]);
    if (existingInvoices.rows.length === 0) {
      console.log('Seeding demo invoice with line items...');
      const invoiceInsert = await client.query(`
        INSERT INTO invoices (
          business_id, invoice_number, customer_name, customer_phone, customer_email,
          status, subtotal, tax, total_amount, verification_token, issued_date, due_date, notes
        ) VALUES (
          $1, 'INV-2026-0001', 'Acro Dynamics Corp', '+1 (555) 987-6543', 'ap@acrodynamics.com',
          'ISSUED', 4250.00, 382.50, 4632.50, 'vt_sec_993f8e71b2d49c81', CURRENT_DATE, CURRENT_DATE + INTERVAL '30 days',
          'Payment due within 30 days. Thank you for your business!'
        ) RETURNING id;
      `, [businessId]);

      const invoiceId = invoiceInsert.rows[0].id;

      await client.query(`
        INSERT INTO invoice_items (invoice_id, product_name, description, quantity, unit_price, total_price)
        VALUES 
          ($1, 'Enterprise Server Rack 42U', 'Standard 19-inch steel enclosure with cooling fans', 2, 1250.00, 2500.00),
          ($1, 'Gigabit Managed Switch 48-Port', 'Layer 3 PoE+ managed switch with redundant power', 3, 450.00, 1350.00),
          ($1, 'Cat6A Patch Cables (Pack of 50)', 'Shielded twisted pair 10Gbps patch cables', 4, 100.00, 400.00);
      `, [invoiceId]);

      console.log(`Created demo invoice INV-2026-0001 [${invoiceId}] with token: vt_sec_993f8e71b2d49c81`);
    }

    console.log('Migration & Seeding completed successfully!');
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration();
