-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 029_capability_registry_integrity.sql
-- Module    : Capability Registry Integrity
--
-- Purpose:
--   Harden lifecycle integrity of platform capabilities created by
--   Migration 022.
--
-- Responsibilities:
--   - Prevent active capabilities from being soft deleted
--   - Preserve historical capability versions
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Correct historical schema through a forward-only migration
--   - Database-enforced lifecycle integrity
--   - Soft deletion remains available for historical records
--   - Active capabilities must remain discoverable
--   - No capability execution logic
--   - No health-check execution
--   - No workflow execution
--   - No worker scheduling
--   - No queue management
--   - No runtime orchestration
--   - No plaintext secrets
--
-- Dependencies:
--   - 022_capability_registry.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Prevent Active Capabilities From Being Soft Deleted
-- =============================================================================
--
-- Migration 022 models capability lifecycle using:
--
--     status
--     deleted_at
--
-- Therefore the invalid state is:
--
--     status = 'active'
--     deleted_at IS NOT NULL
--
-- Historical non-active capability versions may still be soft deleted.
-- =============================================================================

ALTER TABLE raamaesha.capabilities
    ADD CONSTRAINT ck_capabilities_active_not_deleted
        CHECK (
            status <> 'active'
            OR deleted_at IS NULL
        );


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_capabilities_active_not_deleted
ON raamaesha.capabilities IS
'Prevents an active capability version from remaining discoverable as active after soft deletion.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;