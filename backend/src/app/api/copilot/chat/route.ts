import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { runCopilotLoop } from '@/lib/copilot/loop';
import { getResolvedProviderConfig } from '@/lib/copilot/settings';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const {
      business_id,
      messages = [],
      screenContext,
      approvedCall,
      declinedCall,
    } = body;

    // Resolve business_id
    let businessId = business_id;
    if (!businessId) {
      const biz = await query('SELECT id FROM businesses ORDER BY created_at ASC LIMIT 1');
      if (biz.rows.length === 0) {
        return NextResponse.json(
          { success: false, error: 'No business profile found in database.' },
          { status: 400 }
        );
      }
      businessId = biz.rows[0].id;
    }

    // Get provider configuration
    const providerConfig = await getResolvedProviderConfig(businessId);

    // Run agent loop
    const result = await runCopilotLoop({
      businessId,
      messages,
      screenContext,
      providerConfig,
      approvedCall,
      declinedCall,
    });

    return NextResponse.json({
      success: true,
      data: result,
    });
  } catch (error: any) {
    console.error('Copilot Chat Error:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Internal copilot error' },
      { status: 500 }
    );
  }
}
