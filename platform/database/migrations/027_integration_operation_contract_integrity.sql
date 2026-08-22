-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 027_integration_operation_contract_integrity.sql
-- Module    : Integration Operation Contract Integrity
--
-- Purpose:
--   Hardens lifecycle integrity of versioned integration operation contracts
--   created by Migration 021.
--
-- Responsibilities:
--   - Prevent active contracts from being soft deleted
--   - Preserve historical contract versions
--   - Preserve one active contract per operation
--   - Correct historical schema through a forward-only migration
--
-- Design Principles:
--   - Correct historical schema without modifying prior migrations
--   - Database-enforced lifecycle integrity
--   - One active, non-deleted contract per operation
--   - Soft deletion remains available for historical records
--   - Contract version history remains preserved
--   - No execution logic
--   - No workflow execution
--   - No worker scheduling
--   - No queue management
--   - No runtime health-check execution
--   - No plaintext secrets
--
-- Dependencies:
--   - 020_integration_operations.sql
--   - 021_integration_operation_contracts.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Prevent Active Contracts From Being Soft Deleted
-- =============================================================================
--
-- An active contract is the contract currently available for runtime
-- discovery.
--
-- A soft-deleted contract must therefore never remain in the active state.
--
-- Migration 021 already guarantees that only one active, non-deleted contract
-- exists per operation.
--
-- This constraint closes the complementary lifecycle integrity gap by
-- preventing the contradictory state:
--
--     status = 'active'
--     deleted_at IS NOT NULL
--
-- Historical contracts may still be soft deleted after they are no longer
-- active.
-- =============================================================================

ALTER TABLE raamaesha.integration_operation_contracts
    ADD CONSTRAINT ck_integration_operation_contracts_active_not_deleted
        CHECK (
            status <> 'active'
            OR deleted_at IS NULL
        );


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_integration_operation_contracts_active_not_deleted
ON raamaesha.integration_operation_contracts IS
'Prevents an integration operation contract from remaining active after soft deletion.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;