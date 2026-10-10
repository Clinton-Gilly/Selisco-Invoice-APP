import { query } from '@/lib/db';

/**
 * The mobile app release that installed apps are told to update to.
 * Stored in the database so it can be changed from /admin/release without a redeploy;
 * the constants below are only used until a release has been saved there.
 */
export interface AppRelease {
  version: string;
  tagName: string;
  releaseName: string;
  releaseNotes: string;
  downloadUrl: string;
  /** Installed versions below this must update before using the app. */
  minVersion: string;
  publishedAt?: string;
}

const DEFAULT_HOST = (process.env.NEXT_PUBLIC_APP_URL || 'https://backend-tau-puce-j0499ijf6d.vercel.app').replace(/\/$/, '');

export const BUNDLED_RELEASE: AppRelease = {
  version: '1.2.0',
  tagName: 'v1.2.0',
  releaseName: 'Selisco Mobile v1.2.0',
  releaseNotes:
    '- New: Quotations. Create price quotes for clients, share them as PDF and convert accepted quotes to invoices.\n' +
    '- AI Assistant: clearer, shorter answers, no more double confirmation, and it can now prepare quotations.\n' +
    '- Undo in the AI Assistant now correctly restores changes.\n' +
    '- Fixed invoice and delivery note numbers clashing after a deletion.',
  downloadUrl: `${DEFAULT_HOST}/selisco.apk`,
  minVersion: '1.0.0',
};

let tableReady = false;

async function ensureReleaseTable() {
  if (tableReady) return;
  await query(`
    CREATE TABLE IF NOT EXISTS app_releases (
      platform VARCHAR(20) PRIMARY KEY,
      version VARCHAR(20) NOT NULL,
      release_notes TEXT NOT NULL DEFAULT '',
      download_url TEXT NOT NULL,
      min_version VARCHAR(20) NOT NULL DEFAULT '1.0.0',
      updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
  `);
  tableReady = true;
}

export function isValidVersion(v: unknown): v is string {
  return typeof v === 'string' && /^\d+\.\d+\.\d+$/.test(v.trim());
}

export function compareVersions(a: string, b: string): number {
  const pa = a.replace(/^v/, '').split('.').map((n) => parseInt(n, 10) || 0);
  const pb = b.replace(/^v/, '').split('.').map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < 3; i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d !== 0) return d > 0 ? 1 : -1;
  }
  return 0;
}

export async function getCurrentRelease(): Promise<AppRelease> {
  try {
    await ensureReleaseTable();
    const res = await query("SELECT * FROM app_releases WHERE platform = 'android'");
    const row = res.rows[0];
    // A release saved in the database wins unless this deployment bundles a newer one.
    if (row && compareVersions(row.version, BUNDLED_RELEASE.version) >= 0) {
      return {
        version: row.version,
        tagName: `v${row.version}`,
        releaseName: `Selisco Mobile v${row.version}`,
        releaseNotes: row.release_notes,
        downloadUrl: row.download_url,
        minVersion: row.min_version,
        publishedAt: new Date(row.updated_at).toISOString(),
      };
    }
  } catch (err) {
    console.error('Failed to read app release from database:', err);
  }
  return BUNDLED_RELEASE;
}

export async function saveRelease(input: {
  version: string;
  releaseNotes: string;
  downloadUrl: string;
  minVersion: string;
}): Promise<AppRelease> {
  await ensureReleaseTable();
  await query(
    `INSERT INTO app_releases (platform, version, release_notes, download_url, min_version, updated_at)
     VALUES ('android', $1, $2, $3, $4, CURRENT_TIMESTAMP)
     ON CONFLICT (platform) DO UPDATE SET
       version = EXCLUDED.version,
       release_notes = EXCLUDED.release_notes,
       download_url = EXCLUDED.download_url,
       min_version = EXCLUDED.min_version,
       updated_at = CURRENT_TIMESTAMP`,
    [input.version.trim(), input.releaseNotes, input.downloadUrl.trim(), input.minVersion.trim()]
  );
  return getCurrentRelease();
}
