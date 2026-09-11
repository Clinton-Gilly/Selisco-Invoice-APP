import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const search = searchParams.get('search');

    let sql = 'SELECT * FROM products';
    const values: any[] = [];

    if (search && search.trim().length > 0) {
      sql += ' WHERE name ILIKE $1 OR item_code ILIKE $1 ORDER BY name ASC';
      values.push(`%${search.trim()}%`);
    } else {
      sql += ' ORDER BY name ASC';
    }

    const res = await query(sql, values);

    return NextResponse.json({
      success: true,
      data: res.rows,
      count: res.rowCount,
    });
  } catch (error: any) {
    console.error('Error fetching products:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to fetch products' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { name, unit_price, item_code, tax_type = 'D-Non VAT' } = body;

    if (!name || name.trim().isEmpty) {
      return NextResponse.json(
        { success: false, error: 'Product name is required' },
        { status: 400 }
      );
    }

    // Get business id
    const bizRes = await query('SELECT id FROM businesses ORDER BY created_at ASC LIMIT 1');
    const businessId = bizRes.rows[0]?.id;

    const price = parseFloat(unit_price) || 0.0;

    const res = await query(
      `INSERT INTO products (business_id, item_code, name, unit_price, tax_type)
       VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT (business_id, name)
       DO UPDATE SET unit_price = EXCLUDED.unit_price, item_code = EXCLUDED.item_code
       RETURNING *;`,
      [businessId, item_code || null, name.trim(), price, tax_type]
    );

    return NextResponse.json({
      success: true,
      data: res.rows[0],
    }, { status: 201 });
  } catch (error: any) {
    console.error('Error creating product:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to save product' },
      { status: 500 }
    );
  }
}
