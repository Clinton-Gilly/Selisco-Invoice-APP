import { NextRequest, NextResponse } from 'next/server';
import { chat } from '@/lib/copilot/adapters';
import { ProviderConfig, SupportedProvider } from '@/lib/copilot/types';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { provider, model, apiKey } = body;

    if (!provider || !model) {
      return NextResponse.json(
        { success: false, error: 'Provider and model are required.' },
        { status: 400 }
      );
    }

    if (!apiKey || !apiKey.trim()) {
      return NextResponse.json(
        { success: false, error: 'Please enter an API key to test connection.' },
        { status: 400 }
      );
    }

    const testConfig: ProviderConfig = {
      provider: provider as SupportedProvider,
      model,
      apiKey: apiKey.trim(),
    };

    // Execute minimal test turn
    const res = await chat(testConfig, {
      system: 'You are an API diagnostic tester.',
      messages: [
        {
          role: 'user',
          text: 'Respond with "connection_verified" in one word.',
        },
      ],
    });

    return NextResponse.json({
      success: true,
      message: 'Connection verified successfully!',
      sampleResponse: res.text.trim(),
    });
  } catch (error: any) {
    console.error('Copilot test connection failed:', error);
    return NextResponse.json(
      {
        success: false,
        error: error.message || 'Connection test failed. Verify key and network access.',
      },
      { status: 400 }
    );
  }
}
