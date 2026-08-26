-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 033_integration_execution_lifecycle_integrity.sql
-- Module    : Integration Execution Lifecycle Integrity
--
-- Purpose:
--   Harden lifecycle consistency of integration executions created by
--   Migration 019 and further protected by Migration 032.
--
-- Responsibilities:
--   - Ensure terminal executions have a start timestamp
--   - Ensure terminal executions have a completion timestamp
--   - Prevent running executions from having a completion timestamp
--   - Prevent pending executions from having execution timestamps
--   - Preserve execution history
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Correct historical schema through a forward-only migration
--   - Database-enforced lifecycle integrity
--   - Execution records remain persistent operational history
--   - Runtime execution remains outside the database
--   - Retry scheduling remains outside the database
--   - Worker execution remains outside the database
--   - No workflow execution
--   - No queue management
--   - No provider-specific execution logic
--   - No plaintext secrets
--
-- Dependencies:
--   - 019_integration_execution.sql
--   - 032_integration_execution_integrity.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Terminal Execution Must Have Started
-- =============================================================================
--
-- A terminal execution represents work that has reached a final lifecycle
-- state. Therefore it must have a known processing start timestamp.
--
-- Terminal states:
--
--     succeeded
--     failed
--     cancelled
--     timed_out
--
-- Pending executions may not yet have started.
-- Running executions are separately protected by Migration 019.
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT ck_integration_executions_terminal_started
        CHECK (
            status IN ('pending', 'running')
            OR started_at IS NOT NULL
        );


-- =============================================================================
-- Terminal Execution Must Have Completed
-- =============================================================================
--
-- Migration 019 already requires terminal executions to have completed_at.
--
-- This migration intentionally preserves that invariant as part of the
-- explicit lifecycle integrity contract.
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT ck_integration_executions_terminal_completion_timestamp
        CHECK (
            status IN ('pending', 'running')
            OR completed_at IS NOT NULL
        );


-- =============================================================================
-- Running Execution Must Not Be Completed
-- =============================================================================
--
-- A running execution has not yet reached a terminal state.
--
-- Therefore:
--
--     status = 'running'
--     completed_at IS NULL
--
-- This prevents a contradictory lifecycle state.
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT ck_integration_executions_running_not_completed
        CHECK (
            status <> 'running'
            OR completed_at IS NULL
        );


-- =============================================================================
-- Pending Execution Must Not Have Started
-- =============================================================================
--
-- Pending means the runtime has not started processing the execution.
--
-- Therefore a pending execution must not already contain a processing
-- start timestamp.
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT ck_integration_executions_pending_not_started
        CHECK (
            status <> 'pending'
            OR started_at IS NULL
        );


-- =============================================================================
-- Pending Execution Must Not Be Completed
-- =============================================================================
--
-- Pending executions have not started and cannot have reached a terminal
-- completion state.
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT ck_integration_executions_pending_not_completed
        CHECK (
            status <> 'pending'
            OR completed_at IS NULL
        );


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_integration_executions_terminal_started
ON raamaesha.integration_executions IS
'Requires terminal integration executions to have a recorded processing start timestamp.';


COMMENT ON CONSTRAINT
    ck_integration_executions_terminal_completion_timestamp
ON raamaesha.integration_executions IS
'Requires terminal integration executions to have a recorded completion timestamp.';


COMMENT ON CONSTRAINT
    ck_integration_executions_running_not_completed
ON raamaesha.integration_executions IS
'Prevents a running integration execution from having a completion timestamp.';


COMMENT ON CONSTRAINT
    ck_integration_executions_pending_not_started
ON raamaesha.integration_executions IS
'Prevents a pending integration execution from having a processing start timestamp.';


COMMENT ON CONSTRAINT
    ck_integration_executions_pending_not_completed
ON raamaesha.integration_executions IS
'Prevents a pending integration execution from having a completion timestamp.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;