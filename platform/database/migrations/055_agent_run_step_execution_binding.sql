-- =============================================================================
-- RaamaEsha OS Founder Edition v1.0
-- Migration : 055_agent_run_step_execution_binding.sql
-- Module    : Agent Runtime / Integration Execution
--
-- Purpose:
--   Establishes the durable relationship between an agent run step and the
--   integration execution associated with that step.
--
-- Architecture:
--
--   Agent Run
--       |
--       v
--   Agent Run Step
--       |
--       | integration_execution_id
--       v
--   Integration Execution
--       |
--       v
--   Integration Operation
--
-- Design Principles:
--   - Reuses the existing integration execution model from Migration 019
--   - Does not create a duplicate execution model
--   - One integration execution may belong to at most one agent run step
--   - Agent run steps remain generic and are not coupled to capabilities
--   - Execution lifecycle remains owned by integration_executions
--   - Retry state remains owned by integration_executions
--   - No secrets or request/response payloads are introduced
--   - Runtime/application layer owns execution orchestration
--
-- Dependencies:
--   - 019_integration_execution.sql
--   - 053_agent_run_foundation.sql
--   - 054_agent_run_steps.sql
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Add Integration Execution Relationship
-- =============================================================================

ALTER TABLE raamaesha.agent_run_steps
    ADD COLUMN IF NOT EXISTS integration_execution_id UUID;

-- =============================================================================
-- Foreign Key
-- =============================================================================
--
-- An agent run step may optionally reference the integration execution that
-- it initiated or represents.
--
-- The relationship is optional because agent run steps are intentionally
-- generic and may represent non-integration activities.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'fk_agent_run_steps_integration_execution'
          AND conrelid = 'raamaesha.agent_run_steps'::regclass
    ) THEN
        ALTER TABLE raamaesha.agent_run_steps
            ADD CONSTRAINT fk_agent_run_steps_integration_execution
            FOREIGN KEY (integration_execution_id)
            REFERENCES raamaesha.integration_executions(id)
            ON UPDATE CASCADE
            ON DELETE RESTRICT;
    END IF;
END
$$;

-- =============================================================================
-- Uniqueness
-- =============================================================================
--
-- A single integration execution represents one logical execution and must
-- not be attached to multiple agent run steps.
--
-- NULL values remain allowed because not every agent run step represents an
-- integration execution.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_agent_run_steps_integration_execution'
          AND conrelid = 'raamaesha.agent_run_steps'::regclass
    ) THEN
        ALTER TABLE raamaesha.agent_run_steps
            ADD CONSTRAINT uq_agent_run_steps_integration_execution
            UNIQUE (integration_execution_id);
    END IF;
END
$$;

-- =============================================================================
-- Index
-- =============================================================================
--
-- The UNIQUE constraint above already provides an index on
-- integration_execution_id. No separate duplicate index is required.
-- =============================================================================

-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON COLUMN raamaesha.agent_run_steps.integration_execution_id IS
'Optional reference to the integration execution associated with this agent run step. Execution lifecycle, retry state, and operational diagnostics remain owned by raamaesha.integration_executions.';

COMMENT ON CONSTRAINT fk_agent_run_steps_integration_execution
    ON raamaesha.agent_run_steps IS
'Links an agent run step to its associated integration execution without duplicating execution state.';

COMMENT ON CONSTRAINT uq_agent_run_steps_integration_execution
    ON raamaesha.agent_run_steps IS
'Ensures one logical integration execution is associated with at most one agent run step.';

COMMIT;
