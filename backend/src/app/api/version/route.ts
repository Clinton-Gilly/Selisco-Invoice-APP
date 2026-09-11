import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

// In-memory cache for GitHub release data to protect against API rate limits
let cachedRelease: {
  timestamp: number;
  data: {
    version: string;
    tagName: string;
    releaseName: string;
    releaseNotes: string;
    downloadUrl: string;
    publishedAt?: string;
  };
} | null = null;

const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

export async function GET() {
  const now = Date.now();
  if (cachedRelease && now - cachedRelease.timestamp < CACHE_TTL_MS) {
    return NextResponse.json({
      success: true,
      data: cachedRelease.data,
      cached: true,
    });
  }

  try {
    const ghRes = await fetch(
      'https://api.github.com/repos/Clinton-Gilly/Selisco-Invoice-APP/releases/latest',
      {
        headers: {
          Accept: 'application/vnd.github.v3+json',
          'User-Agent': 'Selisco-Update-Service',
        },
      }
    );

    if (ghRes.ok) {
      const release = await ghRes.json();
      const tagName = release.tag_name || 'v1.0.1';
      const version = tagName.replace(/^v/, '');
      const releaseData = {
        version,
        tagName,
        releaseName: release.name || `Version ${version}`,
        releaseNotes: release.body || 'New features, improvements and bug fixes.',
        downloadUrl: 'https://backend-tau-puce-j0499ijf6d.vercel.app/selisco.apk',
        publishedAt: release.published_at,
      };

      cachedRelease = {
        timestamp: now,
        data: releaseData,
      };

      return NextResponse.json({
        success: true,
        data: releaseData,
      });
    }
  } catch (err) {
    console.warn('Failed to fetch from GitHub releases:', err);
  }

  // Fallback if cached version exists even if expired
  if (cachedRelease) {
    return NextResponse.json({
      success: true,
      data: cachedRelease.data,
      stale: true,
    });
  }

  return NextResponse.json({
    success: true,
    data: {
      version: '1.0.1',
      tagName: 'v1.0.1',
      releaseName: 'Selisco Mobile v1.0.1',
      releaseNotes: 'Prominent AI Assistant, direct 1-tap invoice sharing to WhatsApp & apps, and system updates.',
      downloadUrl: 'https://backend-tau-puce-j0499ijf6d.vercel.app/selisco.apk',
    },
  });
}
