import { NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';

const HOSTED_VERSION = '1.1.0';
const HOSTED_TAG = 'v1.1.0';
const HOSTED_RELEASE_NAME = 'Selisco Mobile v1.1.0';
const HOSTED_NOTES =
  '• Added financial amounts, item unit prices, and subtotal/tax calculations to Delivery Notes.\n' +
  '• Added Copilot AI Multi-Session Chat History with conversation switcher, + New Chat, and retry support.\n' +
  '• Faster DeepSeek-Chat AI responses and prompt optimizations.\n' +
  '• Direct cloud APK download and performance improvements.';
const DEFAULT_HOST = process.env.NEXT_PUBLIC_APP_URL || 'https://backend-tau-puce-j0499ijf6d.vercel.app';
const HOSTED_DOWNLOAD_URL = `${DEFAULT_HOST.replace(/\/$/, '')}/selisco.apk`;

// In-memory cache for GitHub release data
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

function isVersionNewer(v1: string, v2: string): boolean {
  const p1 = v1.replace(/^v/, '').split('.').map(n => parseInt(n, 10) || 0);
  const p2 = v2.replace(/^v/, '').split('.').map(n => parseInt(n, 10) || 0);
  for (let i = 0; i < 3; i++) {
    const a = p1[i] || 0;
    const b = p2[i] || 0;
    if (a > b) return true;
    if (a < b) return false;
  }
  return false;
}

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
      const tagName = release.tag_name || 'v1.0.0';
      const ghVersion = tagName.replace(/^v/, '');

      // Only use GitHub release if it is newer than our hosted version
      if (isVersionNewer(ghVersion, HOSTED_VERSION)) {
        const releaseData = {
          version: ghVersion,
          tagName,
          releaseName: release.name || `Version ${ghVersion}`,
          releaseNotes: release.body || 'New features, improvements and bug fixes.',
          downloadUrl: HOSTED_DOWNLOAD_URL,
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
    }
  } catch (err) {
    console.warn('Failed to fetch from GitHub releases:', err);
  }

  const hostedData = {
    version: HOSTED_VERSION,
    tagName: HOSTED_TAG,
    releaseName: HOSTED_RELEASE_NAME,
    releaseNotes: HOSTED_NOTES,
    downloadUrl: HOSTED_DOWNLOAD_URL,
    publishedAt: new Date().toISOString(),
  };

  cachedRelease = {
    timestamp: now,
    data: hostedData,
  };

  return NextResponse.json({
    success: true,
    data: hostedData,
  });
}
