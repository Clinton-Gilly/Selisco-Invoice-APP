-- ==============================================================================
-- IN-APP COPILOT SCHEMA: SETTINGS & AUDIT LOGS
-- ==============================================================================

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

CREATE INDEX IF NOT EXISTS idx_copilot_audit_business ON copilot_audit_logs(business_id);
CREATE INDEX IF NOT EXISTS idx_copilot_audit_created ON copilot_audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_copilot_audit_target ON copilot_audit_logs(target_entity, target_id);
