import { query } from '@/lib/db';
import { ProviderConfig, SupportedProvider } from './types';

// Ensure tables exist
let tablesInitialized = false;

export async function ensureCopilotTables(): Promise<void> {
  if (tablesInitialized) return;
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS copilot_settings (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
        provider VARCHAR(50) NOT NULL DEFAULT 'gemini',
        model VARCHAR(100) NOT NULL DEFAULT 'gemini-2.0-flash',
        api_key_encrypted TEXT,
        api_key_preview VARCHAR(10),
        read_only BOOLEAN NOT NULL DEFAULT FALSE,
        confirm_writes BOOLEAN NOT NULL DEFAULT TRUE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT uq_business_copilot UNIQUE(business_id)
      );

      CREATE TABLE IF NOT EXISTS copilot_audit_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
        action_name VARCHAR(100) NOT NULL,
        description TEXT NOT NULL,
        parameters JSONB NOT NULL,
        result JSONB,
        target_entity VARCHAR(50),
        target_id UUID,
        undone BOOLEAN NOT NULL DEFAULT FALSE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    `);
    tablesInitialized = true;
  } catch (err) {
    console.error('Failed to ensure copilot tables exist:', err);
  }
}

export interface ClientCopilotConfig {
  provider: SupportedProvider;
  model: string;
  hasKey: boolean;
  apiKeyPreview?: string;
  readOnly: boolean;
  confirmWrites: boolean;
  savedAt?: string;
}

export async function getCopilotSettings(businessId: string): Promise<ClientCopilotConfig> {
  await ensureCopilotTables();

  const res = await query(
    'SELECT * FROM copilot_settings WHERE business_id = $1 LIMIT 1',
    [businessId]
  );

  if (res.rows.length > 0) {
    const row = res.rows[0];
    return {
      provider: row.provider as SupportedProvider,
      model: row.model,
      hasKey: Boolean(row.api_key_encrypted || getEnvKeyForProvider(row.provider)),
      apiKeyPreview: row.api_key_preview || (getEnvKeyForProvider(row.provider) ? '••••(env)' : undefined),
      readOnly: Boolean(row.read_only),
      confirmWrites: row.confirm_writes !== false,
      savedAt: row.updated_at,
    };
  }

  // Fallback to default environment configuration
  let envProvider: SupportedProvider = 'deepseek';
  let envModel = 'deepseek-chat';
  let hasKey = false;
  let preview: string | undefined;

  if (process.env.DEEPSEEK_API_KEY) {
    envProvider = 'deepseek';
    envModel = 'deepseek-chat';
    hasKey = true;
    preview = `••••${process.env.DEEPSEEK_API_KEY.slice(-4)}`;
  } else if (process.env.GEMINI_API_KEY) {
    envProvider = 'gemini';
    envModel = 'gemini-2.5-flash';
    hasKey = true;
    preview = `••••${process.env.GEMINI_API_KEY.slice(-4)}`;
  } else if (process.env.OPENAI_API_KEY) {
    envProvider = 'openai';
    envModel = 'gpt-4o-mini';
    hasKey = true;
    preview = `••••${process.env.OPENAI_API_KEY.slice(-4)}`;
  } else if (process.env.GROQ_API_KEY) {
    envProvider = 'groq';
    envModel = 'llama-3.3-70b-versatile';
    hasKey = true;
    preview = `••••${process.env.GROQ_API_KEY.slice(-4)}`;
  } else if (process.env.ANTHROPIC_API_KEY) {
    envProvider = 'anthropic';
    envModel = 'claude-3-7-sonnet-latest';
    hasKey = true;
    preview = `••••${process.env.ANTHROPIC_API_KEY.slice(-4)}`;
  }

  return {
    provider: envProvider,
    model: envModel,
    hasKey,
    apiKeyPreview: preview,
    readOnly: false,
    confirmWrites: true,
  };
}

export async function saveCopilotSettings(
  businessId: string,
  data: {
    provider: SupportedProvider;
    model: string;
    apiKey?: string;
    readOnly?: boolean;
    confirmWrites?: boolean;
  }
): Promise<ClientCopilotConfig> {
  await ensureCopilotTables();

  const preview = data.apiKey && data.apiKey.trim().length >= 4
    ? `••••${data.apiKey.trim().slice(-4)}`
    : undefined;

  // Insert or update
  const existing = await query(
    'SELECT * FROM copilot_settings WHERE business_id = $1 LIMIT 1',
    [businessId]
  );

  if (existing.rows.length === 0) {
    await query(
      `INSERT INTO copilot_settings (
        business_id, provider, model, api_key_encrypted, api_key_preview, read_only, confirm_writes
      ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        businessId,
        data.provider,
        data.model,
        data.apiKey ? data.apiKey.trim() : null,
        preview || null,
        data.readOnly || false,
        data.confirmWrites !== false,
      ]
    );
  } else {
    if (data.apiKey && data.apiKey.trim().length > 0) {
      await query(
        `UPDATE copilot_settings
         SET provider = $2, model = $3, api_key_encrypted = $4, api_key_preview = $5,
             read_only = $6, confirm_writes = $7, updated_at = CURRENT_TIMESTAMP
         WHERE business_id = $1`,
        [
          businessId,
          data.provider,
          data.model,
          data.apiKey.trim(),
          preview,
          data.readOnly || false,
          data.confirmWrites !== false,
        ]
      );
    } else {
      // Keep existing key
      await query(
        `UPDATE copilot_settings
         SET provider = $2, model = $3, read_only = $4, confirm_writes = $5, updated_at = CURRENT_TIMESTAMP
         WHERE business_id = $1`,
        [businessId, data.provider, data.model, data.readOnly || false, data.confirmWrites !== false]
      );
    }
  }

  return await getCopilotSettings(businessId);
}

export async function getResolvedProviderConfig(businessId: string): Promise<ProviderConfig> {
  await ensureCopilotTables();

  const res = await query(
    'SELECT * FROM copilot_settings WHERE business_id = $1 LIMIT 1',
    [businessId]
  );

  let provider: SupportedProvider = 'gemini';
  let model = 'gemini-2.5-flash';
  let apiKey = '';
  let readOnly = false;
  let confirmWrites = true;

  if (res.rows.length > 0) {
    const row = res.rows[0];
    provider = row.provider as SupportedProvider;
    model = row.model;
    apiKey = row.api_key_encrypted || '';
    readOnly = Boolean(row.read_only);
    confirmWrites = row.confirm_writes !== false;
  }

  // If no DB key, check matching env variable
  if (!apiKey) {
    apiKey = getEnvKeyForProvider(provider) || '';
  }

  if (!apiKey) {
    throw new Error(
      `No API key configured for provider "${provider}". Please configure an API key in Copilot Settings.`
    );
  }

  return {
    provider,
    model,
    apiKey,
    readOnly,
    confirmWrites,
  };
}

function getEnvKeyForProvider(provider: SupportedProvider): string | undefined {
  switch (provider) {
    case 'deepseek':
      return process.env.DEEPSEEK_API_KEY;
    case 'gemini':
      return process.env.GEMINI_API_KEY;
    case 'openai':
      return process.env.OPENAI_API_KEY;
    case 'groq':
      return process.env.GROQ_API_KEY;
    case 'anthropic':
      return process.env.ANTHROPIC_API_KEY;
    default:
      return undefined;
  }
}
