import { NextRequest, NextResponse } from 'next/server';
import { compareVersions, getCurrentRelease, isValidVersion, saveRelease } from '@/lib/release';

export const dynamic = 'force-dynamic';

// GET /api/version - Latest mobile release; installed apps compare against this on launch
export async function GET() {
  const release = await getCurrentRelease();
  return NextResponse.json({ success: true, data: release });
}

// POST /api/version - Publish a new release remotely (requires RELEASE_ADMIN_TOKEN)
export async function POST(request: NextRequest) {
  const adminToken = process.env.RELEASE_ADMIN_TOKEN;
  if (!adminToken) {
    return NextResponse.json(
      { success: false, error: 'Remote releases are disabled: RELEASE_ADMIN_TOKEN is not configured.' },
      { status: 503 }
    );
  }
  if (request.headers.get('x-admin-token') !== adminToken) {
    return NextResponse.json({ success: false, error: 'Invalid admin token.' }, { status: 401 });
  }

  try {
    const body = await request.json();
    const { version, releaseNotes = '', downloadUrl, minVersion = '1.0.0' } = body;

    if (!isValidVersion(version)) {
      return NextResponse.json({ success: false, error: 'Version must look like 1.2.0' }, { status: 400 });
    }
    if (!isValidVersion(minVersion)) {
      return NextResponse.json({ success: false, error: 'Minimum version must look like 1.0.0' }, { status: 400 });
    }
    if (compareVersions(minVersion, version) > 0) {
      return NextResponse.json(
        { success: false, error: 'Minimum version cannot be higher than the latest version.' },
        { status: 400 }
      );
    }
    if (typeof downloadUrl !== 'string' || !/^https:\/\//.test(downloadUrl.trim())) {
      return NextResponse.json(
        { success: false, error: 'Download link must be an https:// URL to the APK.' },
        { status: 400 }
      );
    }

    const release = await saveRelease({ version, releaseNotes: String(releaseNotes), downloadUrl, minVersion });
    return NextResponse.json({ success: true, data: release });
  } catch (error: any) {
    console.error('Failed to save release:', error);
    return NextResponse.json(
      { success: false, error: error.message || 'Failed to save release' },
      { status: 500 }
    );
  }
}
