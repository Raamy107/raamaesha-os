-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 034_integration_execution_operation_integrity.sql
-- Module    : Integration Execution Operation Integrity
--
-- Purpose:
--   Hardens referential integrity between integration executions and the
--   organization-owned integration operations they execute.
--
-- Responsibilities:
--   - Execution-to-operation referential integrity
--   - Tenant-safe integration ownership enforcement
--   - Historical execution protection
--
-- Design Principles:
--   - Provider agnostic
--   - Multi-tenant through integration ownership
--   - Composite relationship is tenant-safe
--   - Historical executions remain valid
--   - Soft-deleted operations remain referentially valid
--   - No runtime execution logic
--   - No retry logic
--   - No scheduling logic
--   - No provider-specific business logic
--
-- Dependencies:
--   - 019_integration_execution.sql
--   - 020_integration_operations.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Production Integrity : Execution Operation Relationship
-- =============================================================================
--
-- Every integration execution must reference an operation belonging to the
-- same integration.
--
-- Migration 020 establishes:
--
--     UNIQUE (integration_id, code)
--
-- on raamaesha.integration_operations.
--
-- Migration 034 therefore uses that composite identity to enforce a
-- tenant-safe execution-to-operation relationship.
--
-- The operation does not need to remain active. Historical executions may
-- legitimately reference operations that have subsequently been disabled
-- or soft-deleted.
-- =============================================================================

ALTER TABLE raamaesha.integration_executions
    ADD CONSTRAINT fk_integration_executions_operation
        FOREIGN KEY (integration_id, operation_code)
        REFERENCES raamaesha.integration_operations
            (integration_id, code)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;


-- =============================================================================
-- Constraint Documentation
-- =============================================================================

COMMENT ON CONSTRAINT fk_integration_executions_operation
ON raamaesha.integration_executions IS
'Ensures every integration execution references an operation belonging to the same integration. Historical executions remain valid even when the operation is later disabled or soft-deleted.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;

