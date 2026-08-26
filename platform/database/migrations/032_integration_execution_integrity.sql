-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 032_integration_execution_integrity.sql
-- Module    : Integration Execution Integrity
--
-- Purpose:
--   Harden lifecycle integrity of integration executions created by
--   Migration 019.
--
-- Responsibilities:
--   - Preserve valid execution lifecycle states
--   - Prevent completed executions from remaining retry-scheduled
--   - Prevent non-terminal executions from carrying completion timestamps
--   - Preserve retry-state consistency
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Correct historical schema through a forward-only migration
--   - Database-enforced lifecycle integrity
--   - Execution records remain operational history
--   - Runtime scheduling remains outside the database
--   - Retry execution remains outside the database
--   - No workflow execution
--   - No worker scheduling
--   - No queue management
--   - No runtime orchestration
--   - No plaintext secrets
--
-- Dependencies:
--   - 019_integration_execution.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Prevent Terminal Executions From Remaining Retry Scheduled
-- =============================================================================
--
-- A terminal execution has completed its lifecycle.
--
-- Therefore the invalid state is:
--
--     status IN ('succeeded', 'failed', 'cancelled', 'timed_out')
--     next_retry_at IS NOT NULL
--
-- Retry scheduling is meaningful only while an execution remains pending or
-- has failed and is eligible for another attempt.
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT ck_integration_executions_terminal_no_retry_schedule
        CHECK (
            status IN ('pending', 'running', 'failed')
            OR next_retry_at IS NULL
        );


-- =============================================================================
-- Prevent Non-Terminal Executions From Being Marked Completed
-- =============================================================================
--
-- Pending and running executions have not reached a terminal lifecycle state.
--
-- Therefore the invalid states are:
--
--     status = 'pending'
--     completed_at IS NOT NULL
--
-- or:
--
--     status = 'running'
--     completed_at IS NOT NULL
--
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT ck_integration_executions_non_terminal_not_completed
        CHECK (
            status IN ('succeeded', 'failed', 'cancelled', 'timed_out')
            OR completed_at IS NULL
        );


-- =============================================================================
-- Terminal Execution Completion Integrity
-- =============================================================================
--
-- Every terminal execution must have a completion timestamp.
--
-- Migration 019 already requires completion timestamps for terminal states.
-- This explicit lifecycle constraint documents and reinforces that invariant
-- as part of the forward-only integrity hardening sequence.
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT ck_integration_executions_terminal_completed_at_required
        CHECK (
            status IN ('pending', 'running')
            OR completed_at IS NOT NULL
        );


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_integration_executions_terminal_no_retry_schedule
ON raamaesha.integration_executions IS
'Prevents terminal integration executions from retaining a future retry schedule.';


COMMENT ON CONSTRAINT
    ck_integration_executions_non_terminal_not_completed
ON raamaesha.integration_executions IS
'Prevents pending or running integration executions from carrying a completion timestamp.';


COMMENT ON CONSTRAINT
    ck_integration_executions_terminal_completed_at_required
ON raamaesha.integration_executions IS
'Ensures every terminal integration execution has a completion timestamp.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;