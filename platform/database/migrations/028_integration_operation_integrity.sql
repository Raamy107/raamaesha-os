-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 028_integration_operation_integrity.sql
-- Module    : Integration Operation Integrity
--
-- Purpose:
--   Harden lifecycle integrity of integration operations created by
--   Migration 020.
--
-- Responsibilities:
--   - Preserve integration ownership
--   - Prevent active operations from being soft deleted
--   - Preserve operation history
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Correct historical schema through a forward-only migration
--   - Database-enforced lifecycle integrity
--   - Soft deletion remains available for historical records
--   - Active operations must remain discoverable
--   - No execution logic
--   - No workflow execution
--   - No worker scheduling
--   - No queue management
--   - No runtime execution
--   - No plaintext secrets
--
-- Dependencies:
--   - 020_integration_operations.sql
--   - 021_integration_operation_contracts.sql
--   - 027_integration_operation_contract_integrity.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Prevent Active Operations From Being Soft Deleted
-- =============================================================================
--
-- Migration 020 models operation lifecycle using:
--
--     is_active
--     deleted_at
--
-- Therefore the invalid state is:
--
--     is_active = TRUE
--     deleted_at IS NOT NULL
--
-- Historical inactive operations may still be soft deleted.
-- =============================================================================

ALTER TABLE raamaesha.integration_operations
    ADD CONSTRAINT ck_integration_operations_active_not_deleted
        CHECK (
            is_active = FALSE
            OR deleted_at IS NULL
        );


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_integration_operations_active_not_deleted
ON raamaesha.integration_operations IS
'Prevents an integration operation from remaining active after soft deletion.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;
