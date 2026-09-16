-- =============================================================================
-- RaamaEsha OS Founder Edition v1.0
-- Migration : 068_nandi_ai_execution_foundation.sql
-- Module    : Nandi Control Plane / AI Execution
--
-- Purpose:
--   Establishes the durable operational record for a logical AI model
--   execution initiated by an Agent Runtime step.
--
-- Architecture:
--
--   Agent Invocation
--        |
--        v
--   Nandi Planning
--        |
--        v
--   Governance Decision
--        |
--        v
--   Execution Dispatch
--        |
--        v
--   Agent Run
--        |
--        v
--   Agent Run Step
--        |
--        v
--   AI Execution
--        |
--        +---- Model Selection
--        |          |
--        |          v
--        |      AI Model
--        |          |
--        |          v
--        |      AI Provider
--
-- Responsibilities:
--   1. AI execution identity
--   2. Tenant ownership
--   3. Runtime invocation/run/step traceability
--   4. Nandi model-selection traceability
--   5. Actual AI model/provider preservation
--   6. AI execution lifecycle
--   7. Retry state tracking
--   8. Provider request/response references
--   9. Safe operational metadata
--  10. Non-secret execution diagnostics
--
-- Explicitly NOT included:
--   - Agent run lifecycle
--   - Agent run step lifecycle
--   - Agent scheduling
--   - Worker execution
--   - Provider credentials
--   - API keys or access tokens
--   - Authorization headers
--   - Hidden chain-of-thought
--   - Conversation history
--   - Agent memory
--   - RAG/knowledge storage
--   - Governance decisions
--   - Model-selection policy
--   - Usage/cost accounting
--
-- Architectural rule:
--   Agent Runtime owns the run and step lifecycle.
--   Nandi owns model selection.
--   AI Execution owns the durable record of the logical AI execution.
--   Actual provider invocation remains outside PostgreSQL.
--
-- Dependencies:
--   053_agent_run_foundation.sql
--   054_agent_run_steps.sql
--   058_nandi_invocation_foundation.sql
--   065_nandi_ai_provider_foundation.sql
--   066_nandi_ai_model_foundation.sql
--   067_nandi_model_selection_foundation.sql
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENUM : AI Execution Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'ai_execution_status'
          AND typnamespace = 'public'::regnamespace
    ) THEN
        CREATE TYPE public.ai_execution_status AS ENUM (
            'pending',
            'running',
            'succeeded',
            'failed',
            'cancelled',
            'timed_out'
        );
    END IF;
END
$$;

-- =============================================================================
-- Tenant-Safe Composite Keys
-- =============================================================================
-- Existing runtime entities use UUID primary keys. Composite unique constraints
-- are added here only where required to establish tenant-safe relationships.
-- The existing primary keys remain authoritative.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_agent_runs_id_organization'
          AND conrelid = 'raamaesha.agent_runs'::regclass
    ) THEN
        ALTER TABLE raamaesha.agent_runs
            ADD CONSTRAINT uq_agent_runs_id_organization
            UNIQUE (id, organization_id);
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_agent_run_steps_id_organization'
          AND conrelid = 'raamaesha.agent_run_steps'::regclass
    ) THEN
        ALTER TABLE raamaesha.agent_run_steps
            ADD CONSTRAINT uq_agent_run_steps_id_organization
            UNIQUE (id, organization_id);
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_agent_invocations_id_organization'
          AND conrelid = 'raamaesha.agent_invocations'::regclass
    ) THEN
        ALTER TABLE raamaesha.agent_invocations
            ADD CONSTRAINT uq_agent_invocations_id_organization
            UNIQUE (id, organization_id);
    END IF;
END
$$;

-- =============================================================================
-- TABLE : AI Executions
-- =============================================================================
--
-- One row represents one logical AI execution.
--
-- Retry scheduling and provider invocation are application/runtime concerns.
-- This table records durable execution state and operational history.
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.ai_executions
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_invocation_id UUID NOT NULL,

    agent_run_id UUID NOT NULL,

    agent_run_step_id UUID NOT NULL,

    model_selection_id UUID NOT NULL,

    ai_model_id UUID NOT NULL,

    ai_provider_id UUID NOT NULL,

    status public.ai_execution_status NOT NULL
        DEFAULT 'pending',

    attempt_no INTEGER NOT NULL
        DEFAULT 1,

    retry_count INTEGER NOT NULL
        DEFAULT 0,

    next_retry_at TIMESTAMPTZ,

    idempotency_key TEXT,

    correlation_id UUID,

    started_at TIMESTAMPTZ,

    completed_at TIMESTAMPTZ,

    duration_ms BIGINT,

    provider_request_id TEXT,

    provider_response_id TEXT,

    request_metadata JSONB NOT NULL
        DEFAULT '{}'::jsonb,

    response_metadata JSONB NOT NULL
        DEFAULT '{}'::jsonb,

    error_code TEXT,

    error_category TEXT,

    error_message TEXT,

    metadata JSONB NOT NULL
        DEFAULT '{}'::jsonb,

    created_by UUID,

    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_ai_executions
        PRIMARY KEY (id),

    CONSTRAINT fk_ai_executions_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_executions_invocation
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_executions_agent_run
        FOREIGN KEY (agent_run_id, organization_id)
        REFERENCES raamaesha.agent_runs(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_executions_agent_run_step
        FOREIGN KEY (agent_run_step_id, organization_id)
        REFERENCES raamaesha.agent_run_steps(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_executions_model_selection
        FOREIGN KEY (model_selection_id, organization_id)
        REFERENCES raamaesha.agent_invocation_model_selections(
            id,
            organization_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_executions_ai_model
        FOREIGN KEY (ai_model_id)
        REFERENCES raamaesha.ai_models(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_executions_ai_provider
        FOREIGN KEY (ai_provider_id)
        REFERENCES raamaesha.ai_providers(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_ai_executions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_ai_executions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_ai_executions_attempt_positive
        CHECK (attempt_no > 0),

    CONSTRAINT ck_ai_executions_retry_count_non_negative
        CHECK (retry_count >= 0),

    CONSTRAINT ck_ai_executions_retry_not_exceed_attempt
        CHECK (retry_count < attempt_no),

    CONSTRAINT ck_ai_executions_idempotency_key_not_blank
        CHECK (
            idempotency_key IS NULL
            OR length(trim(idempotency_key)) > 0
        ),

    CONSTRAINT ck_ai_executions_duration_non_negative
        CHECK (
            duration_ms IS NULL
            OR duration_ms >= 0
        ),

    CONSTRAINT ck_ai_executions_request_metadata_object
        CHECK (
            jsonb_typeof(request_metadata) = 'object'
        ),

    CONSTRAINT ck_ai_executions_response_metadata_object
        CHECK (
            jsonb_typeof(response_metadata) = 'object'
        ),

    CONSTRAINT ck_ai_executions_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        ),

    CONSTRAINT ck_ai_executions_error_code_not_blank
        CHECK (
            error_code IS NULL
            OR length(trim(error_code)) > 0
        ),

    CONSTRAINT ck_ai_executions_error_category_not_blank
        CHECK (
            error_category IS NULL
            OR length(trim(error_category)) > 0
        ),

    CONSTRAINT ck_ai_executions_error_message_not_blank
        CHECK (
            error_message IS NULL
            OR length(trim(error_message)) > 0
        ),

    CONSTRAINT ck_ai_executions_started_before_completed
        CHECK (
            started_at IS NULL
            OR completed_at IS NULL
            OR completed_at >= started_at
        ),

    CONSTRAINT ck_ai_executions_running_started
        CHECK (
            status <> 'running'
            OR started_at IS NOT NULL
        ),

    CONSTRAINT ck_ai_executions_terminal_completed
        CHECK (
            status IN ('pending', 'running')
            OR completed_at IS NOT NULL
        ),

    CONSTRAINT ck_ai_executions_retry_schedule_state
        CHECK (
            next_retry_at IS NULL
            OR status IN ('pending', 'failed')
        )
);

-- =============================================================================
-- Execution Integrity Function
-- =============================================================================
-- Ensures the AI model belongs to the recorded provider and that all
-- execution lineage belongs to the same invocation/plan context.
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_ai_execution_integrity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_model_provider_id UUID;
    v_selection_invocation_id UUID;
    v_selection_plan_id UUID;
    v_invocation_id UUID;
    v_invocation_run_id UUID;
    v_run_organization_id UUID;
    v_step_run_id UUID;
    v_step_organization_id UUID;
BEGIN
    SELECT m.provider_id
      INTO v_model_provider_id
      FROM raamaesha.ai_models m
     WHERE m.id = NEW.ai_model_id;

    IF v_model_provider_id IS NULL THEN
        RAISE EXCEPTION
            'AI execution % references AI model % with no provider',
            NEW.id,
            NEW.ai_model_id;
    END IF;

    IF v_model_provider_id <> NEW.ai_provider_id THEN
        RAISE EXCEPTION
            'AI execution % provider % does not match AI model % provider %',
            NEW.id,
            NEW.ai_provider_id,
            NEW.ai_model_id,
            v_model_provider_id;
    END IF;

    SELECT s.agent_invocation_id
      INTO v_selection_invocation_id
      FROM raamaesha.agent_invocation_model_selections s
     WHERE s.id = NEW.model_selection_id
       AND s.organization_id = NEW.organization_id;

    IF v_selection_invocation_id IS NULL THEN
        RAISE EXCEPTION
            'AI execution % references model selection % that does not belong to organization %',
            NEW.id,
            NEW.model_selection_id,
            NEW.organization_id;
    END IF;

    IF v_selection_invocation_id <> NEW.agent_invocation_id THEN
        RAISE EXCEPTION
            'AI execution % invocation % does not match model selection % invocation %',
            NEW.id,
            NEW.agent_invocation_id,
            NEW.model_selection_id,
            v_selection_invocation_id;
    END IF;

    SELECT s.plan_id
      INTO v_selection_plan_id
      FROM raamaesha.agent_invocation_model_selections s
     WHERE s.id = NEW.model_selection_id
       AND s.organization_id = NEW.organization_id;

    IF v_selection_plan_id IS NULL THEN
        RAISE EXCEPTION
            'AI execution % cannot resolve plan for model selection %',
            NEW.id,
            NEW.model_selection_id;
    END IF;

    SELECT i.id,
           i.agent_run_id
      INTO v_invocation_id,
           v_invocation_run_id
      FROM raamaesha.agent_invocations i
     WHERE i.id = NEW.agent_invocation_id
       AND i.organization_id = NEW.organization_id;

    IF v_invocation_id IS NULL THEN
        RAISE EXCEPTION
            'AI execution % references invocation % outside organization %',
            NEW.id,
            NEW.agent_invocation_id,
            NEW.organization_id;
    END IF;

    IF v_invocation_run_id IS NULL THEN
        RAISE EXCEPTION
            'AI execution % invocation % is not associated with an agent run',
            NEW.id,
            NEW.agent_invocation_id;
    END IF;

    IF v_invocation_run_id <> NEW.agent_run_id THEN
        RAISE EXCEPTION
            'AI execution % agent run % does not match invocation % agent run %',
            NEW.id,
            NEW.agent_run_id,
            NEW.agent_invocation_id,
            v_invocation_run_id;
    END IF;

    SELECT r.organization_id
      INTO v_run_organization_id
      FROM raamaesha.agent_runs r
     WHERE r.id = NEW.agent_run_id;

    IF v_run_organization_id <> NEW.organization_id THEN
        RAISE EXCEPTION
            'AI execution % agent run % does not belong to organization %',
            NEW.id,
            NEW.agent_run_id,
            NEW.organization_id;
    END IF;

    SELECT rs.organization_id,
           rs.agent_run_id
      INTO v_step_organization_id,
           v_step_run_id
      FROM raamaesha.agent_run_steps rs
     WHERE rs.id = NEW.agent_run_step_id;

    IF v_step_organization_id <> NEW.organization_id THEN
        RAISE EXCEPTION
            'AI execution % agent run step % does not belong to organization %',
            NEW.id,
            NEW.agent_run_step_id,
            NEW.organization_id;
    END IF;

    IF v_step_run_id <> NEW.agent_run_id THEN
        RAISE EXCEPTION
            'AI execution % agent run step % does not belong to agent run %',
            NEW.id,
            NEW.agent_run_step_id,
            NEW.agent_run_id;
    END IF;

    IF TG_OP = 'UPDATE' THEN

        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
           OR NEW.agent_invocation_id IS DISTINCT FROM OLD.agent_invocation_id
           OR NEW.agent_run_id IS DISTINCT FROM OLD.agent_run_id
           OR NEW.agent_run_step_id IS DISTINCT FROM OLD.agent_run_step_id
           OR NEW.model_selection_id IS DISTINCT FROM OLD.model_selection_id
           OR NEW.ai_model_id IS DISTINCT FROM OLD.ai_model_id
           OR NEW.ai_provider_id IS DISTINCT FROM OLD.ai_provider_id
           OR NEW.attempt_no IS DISTINCT FROM OLD.attempt_no
           OR NEW.idempotency_key IS DISTINCT FROM OLD.idempotency_key
        THEN
            RAISE EXCEPTION
                'Immutable AI execution identity fields cannot be modified after creation';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;
CREATE TRIGGER trg_ai_executions_integrity
    BEFORE INSERT OR UPDATE
    ON raamaesha.ai_executions
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.enforce_ai_execution_integrity();

-- =============================================================================
-- Trigger : Updated At
-- =============================================================================

DROP TRIGGER IF EXISTS trg_ai_executions_updated_at
    ON raamaesha.ai_executions;

CREATE TRIGGER trg_ai_executions_updated_at
    BEFORE UPDATE
    ON raamaesha.ai_executions
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_ai_executions_organization_id
    ON raamaesha.ai_executions (organization_id);

CREATE INDEX IF NOT EXISTS idx_ai_executions_invocation_id
    ON raamaesha.ai_executions (agent_invocation_id);

CREATE INDEX IF NOT EXISTS idx_ai_executions_agent_run_id
    ON raamaesha.ai_executions (agent_run_id);

CREATE INDEX IF NOT EXISTS idx_ai_executions_agent_run_step_id
    ON raamaesha.ai_executions (agent_run_step_id);

CREATE INDEX IF NOT EXISTS idx_ai_executions_model_selection_id
    ON raamaesha.ai_executions (model_selection_id);

CREATE INDEX IF NOT EXISTS idx_ai_executions_ai_model_id
    ON raamaesha.ai_executions (ai_model_id);

CREATE INDEX IF NOT EXISTS idx_ai_executions_ai_provider_id
    ON raamaesha.ai_executions (ai_provider_id);

CREATE INDEX IF NOT EXISTS idx_ai_executions_status
    ON raamaesha.ai_executions (status);

CREATE INDEX IF NOT EXISTS idx_ai_executions_created_at
    ON raamaesha.ai_executions (created_at);

CREATE INDEX IF NOT EXISTS idx_ai_executions_next_retry
    ON raamaesha.ai_executions (next_retry_at)
    WHERE next_retry_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ai_executions_failed
    ON raamaesha.ai_executions (organization_id, created_at DESC)
    WHERE status = 'failed';

CREATE INDEX IF NOT EXISTS idx_ai_executions_pending
    ON raamaesha.ai_executions (organization_id, created_at)
    WHERE status = 'pending';

CREATE UNIQUE INDEX IF NOT EXISTS ux_ai_executions_organization_idempotency
    ON raamaesha.ai_executions (
        organization_id,
        idempotency_key
    )
    WHERE idempotency_key IS NOT NULL;

-- =============================================================================
-- COMMENTS
-- =============================================================================

COMMENT ON TABLE raamaesha.ai_executions IS
    'Persistent operational records representing logical AI model executions initiated by Agent Runtime steps.';

COMMENT ON COLUMN raamaesha.ai_executions.agent_invocation_id IS
    'Invocation that ultimately caused the AI execution.';

COMMENT ON COLUMN raamaesha.ai_executions.agent_run_id IS
    'Agent Runtime run containing the AI execution.';

COMMENT ON COLUMN raamaesha.ai_executions.agent_run_step_id IS
    'Specific ordered Agent Runtime step that performs or represents the AI execution.';

COMMENT ON COLUMN raamaesha.ai_executions.model_selection_id IS
    'Authoritative Nandi model-selection decision associated with this AI execution.';

COMMENT ON COLUMN raamaesha.ai_executions.ai_model_id IS
    'AI model actually used for the execution. Preserved for historical execution traceability.';

COMMENT ON COLUMN raamaesha.ai_executions.ai_provider_id IS
    'AI provider actually used for the execution. Must match the provider registered by the referenced AI model.';

COMMENT ON COLUMN raamaesha.ai_executions.attempt_no IS
    'Application/runtime execution attempt number for this logical AI execution.';

COMMENT ON COLUMN raamaesha.ai_executions.retry_count IS
    'Number of retries recorded for this logical AI execution. Retry scheduling and execution belong to the runtime layer.';

COMMENT ON COLUMN raamaesha.ai_executions.idempotency_key IS
    'Optional application/runtime key used to correlate or prevent duplicate logical AI executions.';

COMMENT ON COLUMN raamaesha.ai_executions.provider_request_id IS
    'Optional non-secret provider request identifier.';

COMMENT ON COLUMN raamaesha.ai_executions.provider_response_id IS
    'Optional non-secret provider response identifier.';

COMMENT ON COLUMN raamaesha.ai_executions.request_metadata IS
    'Safe operational request metadata. Secrets, credentials, authorization headers, and sensitive payloads must never be stored here.';

COMMENT ON COLUMN raamaesha.ai_executions.response_metadata IS
    'Safe operational response metadata. Secrets, credentials, authorization headers, and sensitive payloads must never be stored here.';

COMMENT ON COLUMN raamaesha.ai_executions.metadata IS
    'Extensible non-secret AI execution metadata.';

COMMENT ON COLUMN raamaesha.ai_executions.error_message IS
    'Non-secret execution diagnostic. Provider credentials, tokens, secrets, and sensitive payloads must never be stored here.';

-- =============================================================================
-- COMMIT
-- =============================================================================

COMMIT;