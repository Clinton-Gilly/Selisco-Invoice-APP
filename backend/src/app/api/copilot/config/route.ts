import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { AVAILABLE_PROVIDERS } from '@/lib/copilot/adapters';
import { getCopilotSettings, saveCopilotSettings } from '@/lib/copilot/settings';

export const dynamic = 'force-dynamic';

async function resolveBusinessId(providedId?: string): Promise<string> {
  if (providedId) return providedId;
  const biz = await query('SELECT id FROM businesses ORDER BY created_at ASC LIMIT 1');
  if (biz.rows.length === 0) {
    throw new Error('No business profile found.');
  }
  return biz.rows[0].id;
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const businessId = await resolveBusinessId(searchParams.get('business_id') || undefined);

    const config = await getCopilotSettings(businessId);

    return NextResponse.json({
      success: true,
      data: {
        config,
        availableProviders: AVAILABLE_PROVIDERS,
      },
    });
  } catch (error: any) {
    console.error('Error fetching copilot config:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to fetch copilot config' },
      { status: 500 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const businessId = await resolveBusinessId(body.business_id);

    const updatedConfig = await saveCopilotSettings(businessId, {
      provider: body.provider,
      model: body.model,
      apiKey: body.apiKey,
      readOnly: body.readOnly,
      confirmWrites: body.confirmWrites,
    });

    return NextResponse.json({
      success: true,
      data: {
        config: updatedConfig,
        availableProviders: AVAILABLE_PROVIDERS,
      },
    });
  } catch (error: any) {
    console.error('Error saving copilot config:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to save copilot config' },
      { status: 500 }
    );
  }
}
