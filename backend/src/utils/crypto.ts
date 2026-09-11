import crypto from 'crypto';

/**
 * Generates a high-entropy, URL-safe verification token.
 * Example: vt_sec_4f9a88c21d7b3109a13b4c
 */
export function generateVerificationToken(): string {
  return `vt_${crypto.randomBytes(16).toString('hex')}`;
}

/**
 * Validates a verification token format to avoid malformed queries.
 */
export function isValidTokenFormat(token: string): boolean {
  return typeof token === 'string' && token.length >= 10 && token.length <= 64;
}
