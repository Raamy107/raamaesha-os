-- =============================================================================
-- RaamaEsha OS Founder Edition v1.0
-- Migration : 054_agent_run_steps.sql
-- Module    : Agent Runtime
--
-- Purpose:
--   Creates the durable execution-step model for agent runs.
--
-- Design:
--   Migration 053 records the lifecycle of an agent run.
--   Migration 054 records the ordered execution steps within that run.
--
-- Security:
--   Runtime input/output/metadata/error fields are intended for non-secret
--   operational data only. Secrets, credentials, API keys, and tokens must
--   never be stored in this table.
--
-- Dependencies:
--   053_agent_run_foundation.sql
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENUM : agent_run_step_status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'agent_run_step_status'
          AND typnamespace = 'public'::regnamespace
    ) THEN
        CREATE TYPE public.agent_run_step_status AS ENUM (
            'pending',
            'running',
            'completed',
            'failed',
            'cancelled'
        );
    END IF;
END
$$;

-- =============================================================================
-- TABLE : agent_run_steps
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.agent_run_steps
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_run_id UUID NOT NULL,

    sequence_no INTEGER NOT NULL,

    step_type TEXT NOT NULL,

    status public.agent_run_step_status NOT NULL DEFAULT 'pending',

    name TEXT,

    input JSONB NOT NULL DEFAULT '{}'::jsonb,

    output JSONB NOT NULL DEFAULT '{}'::jsonb,

    started_at TIMESTAMPTZ,

    completed_at TIMESTAMPTZ,

    error_code TEXT,

    error_category TEXT,

    error_message TEXT,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_by UUID,

    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_agent_run_steps
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_run_steps_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_run_steps_run
        FOREIGN KEY (agent_run_id)
        REFERENCES raamaesha.agent_runs(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_run_steps_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_run_steps_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_agent_run_steps_sequence_positive
        CHECK (sequence_no > 0),

    CONSTRAINT ck_agent_run_steps_type_not_blank
        CHECK (btrim(step_type) <> ''),

    CONSTRAINT ck_agent_run_steps_input_object
        CHECK (jsonb_typeof(input) = 'object'),

    CONSTRAINT ck_agent_run_steps_output_object
        CHECK (jsonb_typeof(output) = 'object'),

    CONSTRAINT ck_agent_run_steps_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object'),

    CONSTRAINT ck_agent_run_steps_error_consistency
        CHECK (
            status <> 'failed'
            OR error_message IS NOT NULL
        ),

    CONSTRAINT ck_agent_run_steps_lifecycle_timestamps
        CHECK (
            (
                status = 'pending'
                AND started_at IS NULL
                AND completed_at IS NULL
            )
            OR
            (
                status = 'running'
                AND started_at IS NOT NULL
                AND completed_at IS NULL
            )
            OR
            (
                status IN ('completed', 'failed', 'cancelled')
                AND started_at IS NOT NULL
                AND completed_at IS NOT NULL
            )
        ),

    CONSTRAINT ck_agent_run_steps_completion_after_start
        CHECK (
            completed_at IS NULL
            OR started_at IS NULL
            OR completed_at >= started_at
        )
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_agent_run_steps_organization_id
    ON raamaesha.agent_run_steps (organization_id);

CREATE INDEX IF NOT EXISTS idx_agent_run_steps_agent_run_id
    ON raamaesha.agent_run_steps (agent_run_id);

CREATE INDEX IF NOT EXISTS idx_agent_run_steps_run_sequence
    ON raamaesha.agent_run_steps (agent_run_id, sequence_no);

CREATE INDEX IF NOT EXISTS idx_agent_run_steps_status
    ON raamaesha.agent_run_steps (status);

CREATE INDEX IF NOT EXISTS idx_agent_run_steps_created_at
    ON raamaesha.agent_run_steps (created_at);

CREATE INDEX IF NOT EXISTS idx_agent_run_steps_deleted_at
    ON raamaesha.agent_run_steps (deleted_at);

-- =============================================================================
-- LIFECYCLE FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_agent_run_step_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN

        IF OLD.status IN (
            'completed',
            'failed',
            'cancelled'
        )
        AND NEW.status IS DISTINCT FROM OLD.status THEN
            RAISE EXCEPTION
                'Agent run step % is terminal and cannot change status from %',
                OLD.id,
                OLD.status;
        END IF;

        IF OLD.status = 'pending'
           AND NEW.status NOT IN (
               'pending',
               'running'
           ) THEN
            RAISE EXCEPTION
                'Invalid agent run step lifecycle transition: pending -> %',
                NEW.status;
        END IF;

        IF OLD.status = 'running'
           AND NEW.status NOT IN (
               'running',
               'completed',
               'failed',
               'cancelled'
           ) THEN
            RAISE EXCEPTION
                'Invalid agent run step lifecycle transition: running -> %',
                NEW.status;
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- TRIGGERS
-- =============================================================================

DROP TRIGGER IF EXISTS trg_agent_run_steps_lifecycle
    ON raamaesha.agent_run_steps;

CREATE TRIGGER trg_agent_run_steps_lifecycle
    BEFORE INSERT OR UPDATE
    ON raamaesha.agent_run_steps
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.enforce_agent_run_step_lifecycle();

DROP TRIGGER IF EXISTS trg_agent_run_steps_updated_at
    ON raamaesha.agent_run_steps;

CREATE TRIGGER trg_agent_run_steps_updated_at
    BEFORE UPDATE
    ON raamaesha.agent_run_steps
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE raamaesha.agent_run_steps IS
    'Durable ordered execution steps belonging to AI agent runs.';

COMMENT ON COLUMN raamaesha.agent_run_steps.step_type IS
    'Runtime step classification. Values are intentionally extensible and must not contain secrets.';

COMMENT ON COLUMN raamaesha.agent_run_steps.input IS
    'Non-secret runtime input represented as a JSON object.';

COMMENT ON COLUMN raamaesha.agent_run_steps.output IS
    'Non-secret runtime output represented as a JSON object.';

COMMENT ON COLUMN raamaesha.agent_run_steps.metadata IS
    'Non-secret runtime metadata stored as a JSON object.';

COMMENT ON COLUMN raamaesha.agent_run_steps.error_message IS
    'Runtime failure description; sensitive secrets must never be stored here.';

COMMIT;