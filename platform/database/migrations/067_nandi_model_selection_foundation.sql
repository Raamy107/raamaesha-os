-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 067_nandi_model_selection_foundation.sql
-- Module    : Nandi AI Control Plane
--
-- Purpose:
--   Records the authoritative AI model-selection decision made by Nandi
--   for a specific agent invocation plan.
--
-- Architecture:
--   Agent Invocation
--       -> Context Package
--       -> Nandi Plan (062)
--       -> Model Selection (067)
--       -> AI Model (066)
--       -> AI Provider (065)
--
-- Boundaries:
--   - Does not store credentials or secrets.
--   - Does not execute AI models.
--   - Does not perform governance authorization.
--   - Does not record usage or cost.
--   - Preserves historical model-selection decisions.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n
            ON n.oid = t.typnamespace
        WHERE n.nspname = 'raamaesha'
          AND t.typname = 'agent_invocation_model_selection_status'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_model_selection_status AS ENUM (
            'selecting',
            'selected',
            'failed',
            'superseded'
        );
    END IF;
END
$$;

-- =============================================================================
-- Model Selection
-- =============================================================================

-- =============================================================================
-- Tenant-Safe Parent Key for Nandi Plans
--
-- Migration 062 created the planning table with a primary key on id.
-- Migration 067 requires a tenant-safe composite reference.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'raamaesha'
          AND tablename = 'agent_invocation_plans'
          AND indexname = 'uq_agent_invocation_plans_id_organization'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'raamaesha.agent_invocation_plans'::regclass
          AND conname = 'uq_agent_invocation_plans_id_organization'
    ) THEN
        ALTER TABLE raamaesha.agent_invocation_plans
            ADD CONSTRAINT uq_agent_invocation_plans_id_organization
            UNIQUE (id, organization_id);
    END IF;
END
$$;
CREATE TABLE raamaesha.agent_invocation_model_selections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_invocation_id UUID NOT NULL,

    plan_id UUID NOT NULL,

    selection_version INTEGER NOT NULL DEFAULT 1,

    status raamaesha.agent_invocation_model_selection_status
        NOT NULL DEFAULT 'selecting',

    ai_model_id UUID NOT NULL,

    selection_policy_ref TEXT NULL,

    selection_reason TEXT NOT NULL,

    selection_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    candidate_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    error_code TEXT NULL,

    error_message TEXT NULL,

    error_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_by UUID NULL,

    updated_by UUID NULL,

    deleted_at TIMESTAMPTZ NULL,

    -- -------------------------------------------------------------------------
    -- Organization
    -- -------------------------------------------------------------------------

    CONSTRAINT fk_agent_invocation_model_selections_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- -------------------------------------------------------------------------
    -- Tenant-safe Invocation
    -- -------------------------------------------------------------------------

    CONSTRAINT fk_agent_invocation_model_selections_invocation_organization
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- -------------------------------------------------------------------------
    -- Tenant-safe Plan
    -- -------------------------------------------------------------------------

    CONSTRAINT fk_agent_invocation_model_selections_plan_organization
        FOREIGN KEY (plan_id, organization_id)
        REFERENCES raamaesha.agent_invocation_plans(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- -------------------------------------------------------------------------
    -- AI Model Registry
    -- -------------------------------------------------------------------------

    CONSTRAINT fk_agent_invocation_model_selections_ai_model
        FOREIGN KEY (ai_model_id)
        REFERENCES raamaesha.ai_models(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- -------------------------------------------------------------------------
    -- Audit Actors
    -- -------------------------------------------------------------------------

    CONSTRAINT fk_agent_invocation_model_selections_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_model_selections_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    -- -------------------------------------------------------------------------
    -- Selection Version
    -- -------------------------------------------------------------------------

    CONSTRAINT ck_agent_invocation_model_selections_version
        CHECK (selection_version >= 1),

    -- -------------------------------------------------------------------------
    -- Text Integrity
    -- -------------------------------------------------------------------------

    CONSTRAINT ck_agent_invocation_model_selections_selection_policy_ref
        CHECK (
            selection_policy_ref IS NULL
            OR btrim(selection_policy_ref) <> ''
        ),

    CONSTRAINT ck_agent_invocation_model_selections_selection_reason
        CHECK (btrim(selection_reason) <> ''),

    CONSTRAINT ck_agent_invocation_model_selections_error_code
        CHECK (
            error_code IS NULL
            OR btrim(error_code) <> ''
        ),

    CONSTRAINT ck_agent_invocation_model_selections_error_message
        CHECK (
            error_message IS NULL
            OR btrim(error_message) <> ''
        ),

    -- -------------------------------------------------------------------------
    -- JSON Object Integrity
    -- -------------------------------------------------------------------------

    CONSTRAINT ck_agent_invocation_model_selections_selection_metadata_object
        CHECK (jsonb_typeof(selection_metadata) = 'object'),

    CONSTRAINT ck_agent_invocation_model_selections_candidate_metadata_object
        CHECK (jsonb_typeof(candidate_metadata) = 'object'),

    CONSTRAINT ck_agent_invocation_model_selections_error_metadata_object
        CHECK (jsonb_typeof(error_metadata) = 'object'),

    -- -------------------------------------------------------------------------
    -- Lifecycle Integrity
    -- -------------------------------------------------------------------------

    CONSTRAINT ck_agent_invocation_model_selections_lifecycle
        CHECK (
            (
                status = 'selecting'
                AND error_code IS NULL
                AND error_message IS NULL
            )
            OR
            (
                status = 'selected'
                AND error_code IS NULL
                AND error_message IS NULL
            )
            OR
            (
                status = 'failed'
                AND error_code IS NOT NULL
                AND error_message IS NOT NULL
            )
            OR
            (
                status = 'superseded'
                AND error_code IS NULL
                AND error_message IS NULL
            )
        )

);

-- =============================================================================
-- Historical / Lookup Indexes
-- =============================================================================

CREATE INDEX ix_agent_invocation_model_selections_invocation
    ON raamaesha.agent_invocation_model_selections (agent_invocation_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocation_model_selections_plan
    ON raamaesha.agent_invocation_model_selections (plan_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocation_model_selections_model
    ON raamaesha.agent_invocation_model_selections (ai_model_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocation_model_selections_organization_status
    ON raamaesha.agent_invocation_model_selections
        (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocation_model_selections_plan_version
    ON raamaesha.agent_invocation_model_selections
        (plan_id, selection_version)
    WHERE deleted_at IS NULL;

-- Only one active record may occupy a particular plan/version.
CREATE UNIQUE INDEX uq_agent_invocation_model_selections_active_version
    ON raamaesha.agent_invocation_model_selections
        (plan_id, selection_version)
    WHERE deleted_at IS NULL;

-- Tenant-safe parent key for future composite foreign keys.
CREATE UNIQUE INDEX uq_agent_invocation_model_selections_id_organization
    ON raamaesha.agent_invocation_model_selections
        (id, organization_id);

-- =============================================================================
-- Updated At
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.set_agent_invocation_model_selections_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_agent_invocation_model_selections_updated_at
BEFORE UPDATE
ON raamaesha.agent_invocation_model_selections
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.set_agent_invocation_model_selections_updated_at();

-- =============================================================================
-- Immutability
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_agent_invocation_model_selections_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'selecting' THEN
            RAISE EXCEPTION
                'Agent invocation model selection % must be inserted in selecting status',
                NEW.id;
        END IF;

        RETURN NEW;
    END IF;

    IF OLD.status IN ('selected', 'failed', 'superseded') THEN
        RAISE EXCEPTION
            'Agent invocation model selection % is immutable because its status is %',
            OLD.id,
            OLD.status;
    END IF;

    IF OLD.status = 'selecting' THEN
        IF TG_OP = 'UPDATE'
           AND NEW.status IN ('selected', 'failed')
           AND NEW.id = OLD.id
           AND NEW.organization_id = OLD.organization_id
           AND NEW.agent_invocation_id = OLD.agent_invocation_id
           AND NEW.plan_id = OLD.plan_id
           AND NEW.selection_version = OLD.selection_version
           AND NEW.ai_model_id = OLD.ai_model_id
           AND NEW.selection_policy_ref IS NOT DISTINCT FROM OLD.selection_policy_ref
           AND NEW.selection_reason = OLD.selection_reason
           AND NEW.selection_metadata = OLD.selection_metadata
           AND NEW.candidate_metadata = OLD.candidate_metadata
           AND NEW.error_code IS NOT DISTINCT FROM OLD.error_code
           AND NEW.error_message IS NOT DISTINCT FROM OLD.error_message
           AND NEW.error_metadata = OLD.error_metadata
           AND NEW.created_at = OLD.created_at
           AND NEW.created_by IS NOT DISTINCT FROM OLD.created_by
           AND NEW.deleted_at IS NOT DISTINCT FROM OLD.deleted_at
        THEN
            RETURN NEW;
        END IF;

        RAISE EXCEPTION
            'Agent invocation model selection % is immutable in selecting status except for selecting-to-selected or selecting-to-failed transition',
            OLD.id;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Agent invocation model selection % cannot be deleted',
            OLD.id;
    END IF;

    RETURN NEW;
END;
$function$;

CREATE TRIGGER trg_agent_invocation_model_selections_immutability
BEFORE INSERT OR DELETE OR UPDATE
ON raamaesha.agent_invocation_model_selections
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_agent_invocation_model_selections_mutability();

-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.agent_invocation_model_selections IS
'Records Nandi''s authoritative AI model-selection decision for an agent invocation plan.';

COMMENT ON COLUMN raamaesha.agent_invocation_model_selections.ai_model_id IS
'References the authoritative AI model registry entry from migration 066.';

COMMENT ON COLUMN raamaesha.agent_invocation_model_selections.selection_policy_ref IS
'Optional reference identifying the model-selection policy or rule used by Nandi.';

COMMENT ON COLUMN raamaesha.agent_invocation_model_selections.selection_reason IS
'Human-readable explanation of why the selected AI model was chosen.';

COMMENT ON COLUMN raamaesha.agent_invocation_model_selections.selection_metadata IS
'Structured metadata describing the model-selection decision.';

COMMENT ON COLUMN raamaesha.agent_invocation_model_selections.candidate_metadata IS
'Structured evidence about evaluated model candidates; not the authoritative model registry.';

COMMENT ON COLUMN raamaesha.agent_invocation_model_selections.selection_version IS
'Historical selection version for the associated Nandi plan.';

COMMIT;
