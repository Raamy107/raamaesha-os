-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 066_nandi_ai_model_foundation.sql
-- Module    : Nandi AI Control Plane
--
-- Purpose:
--   Establishes the durable registry of AI models available to Nandi.
--
-- Architecture:
--   AI Provider -> AI Model -> Nandi Model Selection -> Agent Runtime
--
-- Responsibilities:
--   - AI model identity and provider ownership
--   - Model lifecycle management
--   - Provider-specific model identifier
--   - Model classification metadata
--   - Context and output token limits
--
-- Non-responsibilities:
--   - Credentials or API keys
--   - Secrets
--   - Runtime model selection
--   - Prompt storage
--   - Conversation storage
--   - AI execution
--   - Usage or cost accounting
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- AI Model Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'public'::regnamespace
          AND typname = 'ai_model_status'
    ) THEN
        CREATE TYPE public.ai_model_status AS ENUM (
            'draft',
            'active',
            'deprecated',
            'disabled'
        );
    END IF;
END
$$;

-- =============================================================================
-- AI Models
-- =============================================================================

CREATE TABLE raamaesha.ai_models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    provider_id UUID NOT NULL,

    code TEXT NOT NULL,
    name TEXT NOT NULL,
    provider_model_id TEXT NOT NULL,
    description TEXT,

    model_type TEXT NOT NULL,

    status public.ai_model_status NOT NULL
        DEFAULT 'draft',

    context_window_tokens INTEGER,
    max_output_tokens INTEGER,

    capabilities JSONB NOT NULL
        DEFAULT '{}'::jsonb,

    documentation_url TEXT,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by UUID,
    updated_by UUID,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT fk_ai_models_provider
        FOREIGN KEY (provider_id)
        REFERENCES raamaesha.ai_providers(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_models_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_ai_models_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_ai_models_code_nonblank
        CHECK (btrim(code) <> ''),

    CONSTRAINT ck_ai_models_name_nonblank
        CHECK (btrim(name) <> ''),

    CONSTRAINT ck_ai_models_provider_model_id_nonblank
        CHECK (btrim(provider_model_id) <> ''),

    CONSTRAINT ck_ai_models_model_type_nonblank
        CHECK (btrim(model_type) <> ''),

    CONSTRAINT ck_ai_models_context_window_tokens_positive
        CHECK (
            context_window_tokens IS NULL
            OR context_window_tokens > 0
        ),

    CONSTRAINT ck_ai_models_max_output_tokens_positive
        CHECK (
            max_output_tokens IS NULL
            OR max_output_tokens > 0
        ),

    CONSTRAINT ck_ai_models_capabilities_object
        CHECK (
            jsonb_typeof(capabilities) = 'object'
        ),

    CONSTRAINT ck_ai_models_documentation_url_nonblank
        CHECK (
            documentation_url IS NULL
            OR btrim(documentation_url) <> ''
        )
);

-- =============================================================================
-- Indexes
-- =============================================================================

CREATE UNIQUE INDEX uq_ai_models_active_provider_code
    ON raamaesha.ai_models(provider_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_ai_models_provider
    ON raamaesha.ai_models(provider_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_ai_models_status
    ON raamaesha.ai_models(status)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_ai_models_model_type
    ON raamaesha.ai_models(model_type)
    WHERE deleted_at IS NULL;

-- =============================================================================
-- Updated At Function
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_ai_models_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- Updated At Trigger
-- =============================================================================

CREATE TRIGGER trg_ai_models_updated_at
BEFORE UPDATE ON raamaesha.ai_models
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_ai_models_updated_at();

-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.ai_models IS
    'Durable registry of AI models available to the Nandi AI Control Plane.';

COMMENT ON COLUMN raamaesha.ai_models.provider_model_id IS
    'Provider-specific identifier used to address the model through its provider adapter.';

COMMENT ON COLUMN raamaesha.ai_models.model_type IS
    'Flexible model classification used by Nandi for model capability and selection logic.';

COMMENT ON COLUMN raamaesha.ai_models.capabilities IS
    'Extensible model capability metadata. Authoritative authorization remains governed by the Capability and Governance platforms.';

COMMENT ON COLUMN raamaesha.ai_models.context_window_tokens IS
    'Declared model context-window capacity in tokens; runtime enforcement belongs to the provider adapter.';

COMMENT ON COLUMN raamaesha.ai_models.max_output_tokens IS
    'Declared maximum output capacity in tokens; runtime enforcement belongs to the provider adapter.';

-- =============================================================================
-- Completion
-- =============================================================================

COMMIT;
