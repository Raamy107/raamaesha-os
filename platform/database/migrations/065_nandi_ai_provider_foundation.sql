-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 065_nandi_ai_provider_foundation.sql
-- Module    : Nandi AI Platform
--
-- Purpose:
--   Establishes the durable registry of AI service providers used by Nandi.
--
-- Responsibilities:
--   - AI provider identity
--   - Provider classification
--   - Provider documentation reference
--   - Provider lifecycle
--   - Provider metadata
--   - Auditability and soft deletion
--
-- Does NOT:
--   - Store credentials or API keys
--   - Store secrets
--   - Define AI models
--   - Select models
--   - Execute AI requests
--   - Record usage or cost
--   - Duplicate integration providers
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- AI Provider Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n
            ON n.oid = t.typnamespace
        WHERE n.nspname = 'public'
          AND t.typname = 'ai_provider_status'
    ) THEN
        CREATE TYPE public.ai_provider_status AS ENUM (
            'draft',
            'active',
            'deprecated',
            'disabled'
        );
    END IF;
END
$$;

-- =============================================================================
-- AI Providers
-- =============================================================================

CREATE TABLE raamaesha.ai_providers (
    id UUID NOT NULL DEFAULT gen_random_uuid(),

    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT NULL,

    provider_type TEXT NOT NULL,
    documentation_url TEXT NULL,

    status public.ai_provider_status NOT NULL
        DEFAULT 'draft',

    metadata JSONB NOT NULL
        DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by UUID NULL,
    updated_by UUID NULL,

    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT ai_providers_pkey
        PRIMARY KEY (id),

    CONSTRAINT ck_ai_providers_code_nonblank
        CHECK (btrim(code) <> ''),

    CONSTRAINT ck_ai_providers_name_nonblank
        CHECK (btrim(name) <> ''),

    CONSTRAINT ck_ai_providers_provider_type_nonblank
        CHECK (btrim(provider_type) <> ''),

    CONSTRAINT ck_ai_providers_documentation_url_nonblank
        CHECK (
            documentation_url IS NULL
            OR btrim(documentation_url) <> ''
        ),

    CONSTRAINT ck_ai_providers_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        ),

    CONSTRAINT fk_ai_providers_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_ai_providers_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);

-- =============================================================================
-- Provider Code Uniqueness
-- =============================================================================

CREATE UNIQUE INDEX uq_ai_providers_active_code
    ON raamaesha.ai_providers (code)
    WHERE deleted_at IS NULL;

-- =============================================================================
-- Query Indexes
-- =============================================================================

CREATE INDEX ix_ai_providers_status
    ON raamaesha.ai_providers (status)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_ai_providers_provider_type
    ON raamaesha.ai_providers (provider_type)
    WHERE deleted_at IS NULL;

-- =============================================================================
-- Updated-At Function
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.set_ai_providers_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- Updated-At Trigger
-- =============================================================================

CREATE TRIGGER trg_ai_providers_updated_at
BEFORE UPDATE ON raamaesha.ai_providers
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_ai_providers_updated_at();

-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.ai_providers IS
    'Durable registry of AI service providers used by the Nandi AI Control Plane.';

COMMENT ON COLUMN raamaesha.ai_providers.provider_type IS
    'Provider classification used by Nandi for provider capability and adapter resolution.';

COMMENT ON COLUMN raamaesha.ai_providers.metadata IS
    'Non-secret provider metadata. Credentials and secrets must never be stored here.';

COMMENT ON COLUMN raamaesha.ai_providers.documentation_url IS
    'Reference URL for provider documentation or integration guidance.';

COMMIT;
