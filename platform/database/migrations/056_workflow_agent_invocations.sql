-- =============================================================================
-- RaamaEsha OS Founder Edition v1.0
-- Migration : 056_workflow_agent_invocations.sql
-- Module    : Workflow <-> Agent Runtime Bridge
--
-- Purpose:
--   Creates the durable relationship between a workflow step execution
--   attempt and the agent run invoked by that attempt.
--
-- Architecture:
--   Workflow Step Execution
--          |
--          v
--   Workflow Agent Invocation
--          |
--          v
--   Agent Run
--
-- Design principles:
--   - Workflow runtime owns workflow execution semantics.
--   - Agent Runtime owns agent execution lifecycle.
--   - One workflow step execution attempt may invoke at most one agent run.
--   - Agent Run owns runtime status and lifecycle.
--   - Workflow retry semantics remain owned by workflow_step_executions.
--   - Integration retry semantics remain owned by integration_executions.
--   - No duplicate agent, capability, integration, execution, or retry state.
--   - No secrets or request/response payloads are stored here.
--   - Cross-tenant associations are explicitly enforced.
--
-- Dependencies:
--   050_workflow_foundation.sql
--   053_agent_run_foundation.sql
--   054_agent_run_steps.sql
--
-- =============================================================================

BEGIN;

-- =============================================================================
-- TABLE : workflow_agent_invocations
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.workflow_agent_invocations
(
    id UUID NOT NULL DEFAULT gen_random_uuid(),

    workflow_step_execution_id UUID NOT NULL,
    agent_run_id UUID NOT NULL,

    correlation_id UUID,

    created_by UUID,
    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_workflow_agent_invocations
        PRIMARY KEY (id),

    CONSTRAINT fk_workflow_agent_invocations_step_execution
        FOREIGN KEY (workflow_step_execution_id)
        REFERENCES raamaesha.workflow_step_executions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_workflow_agent_invocations_agent_run
        FOREIGN KEY (agent_run_id)
        REFERENCES raamaesha.agent_runs(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_workflow_agent_invocations_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_workflow_agent_invocations_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT uq_workflow_agent_invocations_step_execution
        UNIQUE (workflow_step_execution_id)
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS ix_workflow_agent_invocations_agent_run
    ON raamaesha.workflow_agent_invocations(agent_run_id);

CREATE INDEX IF NOT EXISTS ix_workflow_agent_invocations_created_at
    ON raamaesha.workflow_agent_invocations(created_at DESC);

CREATE INDEX IF NOT EXISTS ix_workflow_agent_invocations_deleted_at
    ON raamaesha.workflow_agent_invocations(deleted_at);

CREATE INDEX IF NOT EXISTS ix_workflow_agent_invocations_correlation_id
    ON raamaesha.workflow_agent_invocations(correlation_id)
    WHERE correlation_id IS NOT NULL;

-- =============================================================================
-- TENANT INTEGRITY
--
-- Workflow step execution resolves to:
--   workflow_instance.organization_id
--
-- Agent run directly owns:
--   agent_runs.organization_id
--
-- These organizations must match.
-- =============================================================================

CREATE OR REPLACE FUNCTION
raamaesha.enforce_workflow_agent_invocation_tenant_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    workflow_organization_id UUID;
    agent_organization_id UUID;
BEGIN
    SELECT wi.organization_id
      INTO workflow_organization_id
      FROM raamaesha.workflow_step_executions AS wse
      INNER JOIN raamaesha.workflow_instances AS wi
              ON wi.id = wse.workflow_instance_id
     WHERE wse.id = NEW.workflow_step_execution_id;

    IF workflow_organization_id IS NULL THEN
        RAISE EXCEPTION
            'Workflow step execution % does not resolve to a valid organization',
            NEW.workflow_step_execution_id
            USING ERRCODE = '23503';
    END IF;

    SELECT ar.organization_id
      INTO agent_organization_id
      FROM raamaesha.agent_runs AS ar
     WHERE ar.id = NEW.agent_run_id;

    IF agent_organization_id IS NULL THEN
        RAISE EXCEPTION
            'Agent run % does not resolve to a valid organization',
            NEW.agent_run_id
            USING ERRCODE = '23503';
    END IF;

    IF workflow_organization_id IS DISTINCT FROM agent_organization_id THEN
        RAISE EXCEPTION
            'Workflow step execution % and agent run % belong to different organizations',
            NEW.workflow_step_execution_id,
            NEW.agent_run_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_workflow_agent_invocations_tenant_integrity
    ON raamaesha.workflow_agent_invocations;

CREATE TRIGGER trg_workflow_agent_invocations_tenant_integrity
    BEFORE INSERT OR UPDATE
    ON raamaesha.workflow_agent_invocations
    FOR EACH ROW
    EXECUTE FUNCTION
        raamaesha.enforce_workflow_agent_invocation_tenant_integrity();

-- =============================================================================
-- UPDATED_AT
-- =============================================================================

DROP TRIGGER IF EXISTS trg_workflow_agent_invocations_set_updated_at
    ON raamaesha.workflow_agent_invocations;

CREATE TRIGGER trg_workflow_agent_invocations_set_updated_at
    BEFORE UPDATE
    ON raamaesha.workflow_agent_invocations
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- DOCUMENTATION
-- =============================================================================

COMMENT ON TABLE raamaesha.workflow_agent_invocations IS
    'Durable bridge between a workflow step execution attempt and the agent run invoked by that attempt.';

COMMENT ON COLUMN raamaesha.workflow_agent_invocations.workflow_step_execution_id IS
    'Workflow step execution attempt associated with this agent invocation.';

COMMENT ON COLUMN raamaesha.workflow_agent_invocations.agent_run_id IS
    'Agent Runtime execution record invoked by the workflow step execution.';

COMMENT ON COLUMN raamaesha.workflow_agent_invocations.correlation_id IS
    'Optional cross-platform correlation identifier used for runtime tracing.';

-- =============================================================================
-- COMPLETE
-- =============================================================================

COMMIT;