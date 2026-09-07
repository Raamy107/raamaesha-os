-- =============================================================================
-- RaamaEsha OS Founder Edition v1.0
-- Migration : 053_agent_run_foundation.sql
-- Module    : Agent Runtime
--
-- Purpose:
--   Establish the durable foundation for agent invocation/run history.
--
-- Scope:
--   1. Agent run identity
--   2. Tenant ownership
--   3. Agent instance/version integrity
--   4. Agent run lifecycle
--   5. Correlation support
--   6. Runtime error metadata
--   7. Audit integrity
--   8. Historical execution preservation
--
-- Explicitly NOT included:
--   - Agent memory
--   - Agent conversations
--   - Agent permissions
--   - Capability execution
--   - Integration execution
--   - AI provider execution
--   - Worker scheduling
--   - Queue management
--   - Retry orchestration
--
-- Architectural rule:
--   Agent runs record durable runtime history.
--   Actual execution remains outside PostgreSQL.
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENUM : Agent Run Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'agent_run_status'
          AND typnamespace = 'public'::regnamespace
    ) THEN
        CREATE TYPE public.agent_run_status AS ENUM (
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
-- TABLE : Agent Runs
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.agent_runs
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_instance_id UUID NOT NULL,
    agent_version_id UUID NOT NULL,

    status public.agent_run_status NOT NULL
        DEFAULT 'pending',

    correlation_id UUID,

    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,

    metadata JSONB NOT NULL
        DEFAULT '{}'::jsonb,

    error_code TEXT,
    error_category TEXT,
    error_message TEXT,

    created_by UUID,
    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_agent_runs
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_runs_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_agent_runs_instance_version
        FOREIGN KEY (agent_instance_id, agent_version_id)
        REFERENCES raamaesha.agent_instances(id, agent_version_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_runs_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_runs_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_agent_runs_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        ),

    CONSTRAINT ck_agent_runs_error_consistency
        CHECK (
            status NOT IN ('failed')
            OR error_message IS NOT NULL
        ),

    CONSTRAINT ck_agent_runs_lifecycle_timestamps
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

    CONSTRAINT ck_agent_runs_completion_after_start
        CHECK (
            completed_at IS NULL
            OR started_at IS NULL
            OR completed_at >= started_at
        )
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_agent_runs_organization_id
    ON raamaesha.agent_runs (organization_id);

CREATE INDEX IF NOT EXISTS idx_agent_runs_agent_instance_id
    ON raamaesha.agent_runs (agent_instance_id);

CREATE INDEX IF NOT EXISTS idx_agent_runs_agent_version_id
    ON raamaesha.agent_runs (agent_version_id);

CREATE INDEX IF NOT EXISTS idx_agent_runs_status
    ON raamaesha.agent_runs (status);

CREATE INDEX IF NOT EXISTS idx_agent_runs_created_at
    ON raamaesha.agent_runs (created_at);

CREATE INDEX IF NOT EXISTS idx_agent_runs_deleted_at
    ON raamaesha.agent_runs (deleted_at);

CREATE INDEX IF NOT EXISTS idx_agent_runs_correlation_id
    ON raamaesha.agent_runs (correlation_id)
    WHERE correlation_id IS NOT NULL;

-- =============================================================================
-- FUNCTION : Agent Run Lifecycle Enforcement
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_agent_run_lifecycle()
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
                'Agent run % is terminal and cannot change status from %',
                OLD.id,
                OLD.status;
        END IF;

        IF OLD.status = 'pending'
           AND NEW.status NOT IN (
               'pending',
               'running',
               'failed',
               'cancelled'
           ) THEN
            RAISE EXCEPTION
                'Invalid agent run lifecycle transition: pending -> %',
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
                'Invalid agent run lifecycle transition: running -> %',
                NEW.status;
        END IF;

    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- TRIGGER : Agent Run Lifecycle
-- =============================================================================

DROP TRIGGER IF EXISTS trg_agent_runs_lifecycle
    ON raamaesha.agent_runs;

CREATE TRIGGER trg_agent_runs_lifecycle
    BEFORE INSERT OR UPDATE
    ON raamaesha.agent_runs
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.enforce_agent_run_lifecycle();

-- =============================================================================
-- TRIGGER : Updated At
-- =============================================================================

DROP TRIGGER IF EXISTS trg_agent_runs_updated_at
    ON raamaesha.agent_runs;

CREATE TRIGGER trg_agent_runs_updated_at
    BEFORE UPDATE
    ON raamaesha.agent_runs
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE raamaesha.agent_runs IS
    'Durable runtime invocation history for AI agent instances.';

COMMENT ON COLUMN raamaesha.agent_runs.metadata IS
    'Non-secret runtime metadata stored as a JSON object.';
COMMENT ON COLUMN raamaesha.agent_runs.correlation_id IS
    'Correlation identifier used to connect an agent run with surrounding runtime activity.';

COMMENT ON COLUMN raamaesha.agent_runs.error_message IS
    'Runtime failure description; sensitive secrets must never be stored here.';

-- =============================================================================
-- COMMIT
-- =============================================================================

COMMIT;
