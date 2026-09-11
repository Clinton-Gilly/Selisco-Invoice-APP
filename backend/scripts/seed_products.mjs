import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const envLocalPath = path.resolve(__dirname, '../.env.local');
if (fs.existsSync(envLocalPath)) {
  dotenv.config({ path: envLocalPath });
} else {
  dotenv.config();
}

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.error('ERROR: DATABASE_URL not set');
  process.exit(1);
}

const pool = new pg.Pool({
  connectionString,
  ssl: { rejectUnauthorized: false }
});

const RAW_ITEMS = [
  // From Image 1 (Sample Receipt with known prices)
  { code: 'KE2BLXAVX00001', name: 'Straight T-plate 20x12 holes', price: 15000.00 },
  { code: 'KE2BEXDRX00001', name: 'Straight T-plate 2.4x7 holes', price: 10000.00 },
  { code: 'KE2BVXBLL00001', name: '2.0x5mm Mini screws', price: 1500.00 },
  { code: 'KE2BLXCEL00003', name: '2.4x14mm Mini screws', price: 1500.00 },

  // From Image 2
  { code: 'KE2BAX4BX00001', name: '20 by 6 holes T plate', price: 9500.00 },
  { code: 'KE2BAXBAX00001', name: '24 mandibular plate 8 holes', price: 12000.00 },
  { code: 'KE2BEXAVX00001', name: 'Surgicel', price: 4500.00 },
  { code: 'KE2BFXAVX00001', name: '15 by 5 mm screws', price: 1500.00 },
  { code: 'KE2BQXGRM00001', name: 'Mandibular plate 24 by 6 holes', price: 11000.00 },
  { code: 'KE2BRXBXX00002', name: 'T-Plate 27 holes', price: 16000.00 },
  { code: 'KE2BRXL00001', name: 'T-Plate 20 16 holes', price: 14000.00 },
  { code: 'KE2BZXBLL00001', name: '24 mandibular plate 7 holes', price: 11500.00 },
  { code: 'KE2CAXBGX00001', name: 'Mandibular plate', price: 9000.00 },
  { code: 'KE2CAXCMT00001', name: '26 by 6mm mini screws', price: 1500.00 },
  { code: 'KE2CLXDRX00001', name: 'Mandibular plate 24 by 10 holes', price: 13500.00 },
  { code: 'KE2CLXGLL00001', name: '20 T-plate 9 holes', price: 10500.00 },

  // From Image 3
  { code: 'KE2BAXDRX00001', name: 'C-Shaped 5 holes', price: 8500.00 },
  { code: 'KE2BEXBGX00001', name: '20mm by 5mm screws', price: 1500.00 },
  { code: 'KE2BEXDRX00002', name: 'Straight T-plate 7 holes', price: 9500.00 },
  { code: 'KE2BFXBAX00001', name: 'Bone granules', price: 18000.00 },
  { code: 'KE2BFXCMT00001', name: '24 by 12 screws', price: 1500.00 },
  { code: 'KE2BGXBAX00001', name: 'Straight plate 24 by 7 holes', price: 11000.00 },
  { code: 'KE2BGXBAX00002', name: 'Lateral mass screw', price: 3500.00 },
  { code: 'KE2BGXBEX00001', name: 'Transitional rods', price: 22000.00 },
  { code: 'KE2BGXBGX00001', name: 'C-plate 26 by 8 holes', price: 12500.00 },
  { code: 'KE2BGXBLX00001', name: '20 by 6mm screws', price: 1500.00 },
  { code: 'KE2BGXCEL00001', name: 'C-Shaped 8 holes', price: 10000.00 },
  { code: 'KE2BJXBGX00001', name: 'Straight T plate 20 by 6 holes', price: 9500.00 },
  { code: 'KE2BJXBLL00001', name: 'Arch Bar', price: 6500.00 },
  { code: 'KE2BKXAVX00001', name: 'C Shaped T-plate', price: 11000.00 },
  { code: 'KE2BKXBEX00001', name: 'Straight T-plate 16 holes', price: 13500.00 },
  { code: 'KE2BKXBLL00002', name: 'Left Angled mandibular Recon plate', price: 18500.00 },
  { code: 'KE2BKXCAX00001', name: 'K-wires 18mm', price: 850.00 },
  { code: 'KE2BKXCEL00001', name: '20 T-plate 8 holes', price: 10000.00 },
  { code: 'KE2BKXCMT00002', name: 'Distal femur locking', price: 28000.00 },
  { code: 'KE2BKXCRX00001', name: 'Pedicle screws', price: 4500.00 },
  { code: 'KE2BLXBEX00001', name: 'C - Plate', price: 9500.00 },
  { code: 'KE2BLXBGX00001', name: 'X - Shaped T - Plate', price: 12500.00 },
  { code: 'KE2BLXBLL00001', name: '20 by 6mm mini screw', price: 1500.00 },

  // From Image 4
  { code: 'KE2BRXBLX00001', name: 'L-Shape plate', price: 10500.00 },
  { code: 'KE2BRXBXX00001', name: 'Locking cortical', price: 3200.00 },
  { code: 'KE2BRXCEL00001', name: 'Straight T-plate 20 holes', price: 16000.00 },
  { code: 'KE2BVXDRX00001', name: 'L-Plate 20 by 2 holes', price: 8000.00 },
  { code: 'KE2BZXCRX00001', name: 'Straight 25 by 5 holes', price: 9000.00 },
  { code: 'KE2CAXCEL00002', name: '20 by 10 hole plate', price: 11500.00 },
  { code: 'KE2CAXMGM00001', name: '4.5 cortical screws size 34', price: 1800.00 },
  { code: 'KE2CHXKGX00001', name: 'K wires 1.2mm', price: 850.00 },
  { code: 'KE2CJXCEL00001', name: '24 by 16 Mandibular plate', price: 17500.00 },
  { code: 'KE2CLXBLX00001', name: 'Titanium Cranium mesh 15mm 10mm by 10cm', price: 35000.00 },
  { code: 'KE2CLXDZX00001', name: 'Straight 20 by 5 holes', price: 8500.00 },
  { code: 'KE2CRX00001', name: '4.5 cortical screws size 38', price: 1800.00 },
  { code: 'KE2CRXKTM00001', name: '4.5 cortical screws size 36', price: 1800.00 },
  { code: 'KE2JRXM2X00001', name: 'T plate straight', price: 9500.00 },
  { code: 'KE2MLX00001', name: '4.5 cortical screws size 32', price: 1800.00 },
  { code: 'KE2MLX00002', name: '4.5 cortical screws size 30', price: 1800.00 },
  { code: 'KE2MLX00003', name: '4.5 cortical screws size 28', price: 1800.00 },
  { code: 'KE2MLX00004', name: '4.5 cortical screws size 26', price: 1800.00 },
  { code: 'KE2MLX00005', name: '4.5 cortical screws size 24', price: 1800.00 },
  { code: 'KE2MLX00006', name: '3.5 Cortical screws size 18', price: 1600.00 },
  { code: 'KE2MLX00007', name: 'Rod 30 cm', price: 19500.00 },

  // From Image 5
  { code: 'KE2MLX00014', name: '3.5 Cortical Screws 16mm', price: 1600.00 },
  { code: 'KE2MLX00015', name: '3.5 Lockings 16mm', price: 2400.00 },
  { code: 'KE2MLX00016', name: '3.5 Lockings 14mm', price: 2400.00 },
  { code: 'KE2MLX00017', name: '3.5 Lockings 12mm', price: 2400.00 },
  { code: 'KE2MLX00018', name: '4.0 Drill bit', price: 4200.00 },
  { code: 'KE2MLX00019', name: 'Proximal Tibia 6.5 6 hole', price: 26000.00 },
  { code: 'KE2MLX00020', name: 'Proximal Tibia 3.5 8 hole', price: 24000.00 },
  { code: 'KE2MLX00021', name: 'Shanzs pins', price: 2800.00 },
  { code: 'KE2MLX00022', name: 'K Wires 25mm', price: 950.00 },
  { code: 'KE2MLXBAX00001', name: '27 T-plate 8 holes', price: 10500.00 }
];

async function run() {
  const client = await pool.connect();
  try {
    console.log('1. Updating schema with customer_pin and products table...');
    await client.query(`
      ALTER TABLE invoices ADD COLUMN IF NOT EXISTS customer_pin VARCHAR(50);

      CREATE TABLE IF NOT EXISTS products (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
        item_code VARCHAR(50),
        name VARCHAR(255) NOT NULL,
        unit_price NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
        tax_type VARCHAR(50) DEFAULT 'D-Non VAT',
        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT uq_business_product_name UNIQUE (business_id, name)
      );

      CREATE INDEX IF NOT EXISTS idx_products_business ON products(business_id);
      CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);
    `);

    console.log('2. Updating business record to official SELISCO LTD details...');
    const bizRes = await client.query(`
      UPDATE businesses
      SET 
        name = 'SELISCO LTD',
        phone = '0787371118, 0725822128',
        email = 'seliscoltd@gmail.com',
        currency = 'KES',
        address = 'Location: Soy Arcade behind Naivas Trocadero'
      RETURNING id, name, currency;
    `);

    let businessId;
    if (bizRes.rows.length === 0) {
      const insertBiz = await client.query(`
        INSERT INTO businesses (name, email, phone, currency, address)
        VALUES (
          'SELISCO LTD',
          'seliscoltd@gmail.com',
          '0787371118, 0725822128',
          'KES',
          'Location: Soy Arcade behind Naivas Trocadero'
        ) RETURNING id;
      `);
      businessId = insertBiz.rows[0].id;
    } else {
      businessId = bizRes.rows[0].id;
    }
    console.log(`Business profile updated for: SELISCO LTD [${businessId}] (Currency: KES)`);

    console.log('3. Seeding deduplicated surgical and orthopaedic product catalog...');
    // Deduplicate by lowercase name
    const seen = new Set();
    const uniqueItems = [];
    for (const item of RAW_ITEMS) {
      const key = item.name.trim().toLowerCase();
      if (!seen.has(key)) {
        seen.add(key);
        uniqueItems.push(item);
      }
    }

    let inserted = 0;
    for (const item of uniqueItems) {
      await client.query(`
        INSERT INTO products (business_id, item_code, name, unit_price, tax_type)
        VALUES ($1, $2, $3, $4, 'D-Non VAT')
        ON CONFLICT (business_id, name) 
        DO UPDATE SET unit_price = EXCLUDED.unit_price, item_code = EXCLUDED.item_code;
      `, [businessId, item.code, item.name.trim(), item.price]);
      inserted++;
    }

    console.log(`Successfully seeded ${inserted} unique products into catalog!`);
    console.log('Done!');
  } catch (err) {
    console.error('Migration failed:', err);
    process.exit(1);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
