-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 030_capability_interface_integrity.sql
-- Module    : Capability Interface Integrity
--
-- Purpose:
--   Harden lifecycle integrity of capability APIs and capability events
--   created by Migration 023.
--
-- Responsibilities:
--   - Prevent active capability APIs from being soft deleted
--   - Prevent active capability events from being soft deleted
--   - Preserve historical API and event versions
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Correct historical schema through a forward-only migration
--   - Database-enforced lifecycle integrity
--   - Soft deletion remains available for historical records
--   - Active interfaces must remain discoverable
--   - No API execution logic
--   - No event publication or processing logic
--   - No workflow execution
--   - No worker scheduling
--   - No queue management
--   - No runtime orchestration
--   - No plaintext secrets
--
-- Dependencies:
--   - 023_capability_interfaces.sql
--   - 029_capability_registry_integrity.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Prevent Active Capability APIs From Being Soft Deleted
-- =============================================================================
--
-- Migration 023 models API lifecycle using:
--
--     status
--     deleted_at
--
-- Therefore the invalid state is:
--
--     status = 'active'
--     deleted_at IS NOT NULL
--
-- Historical non-active API versions may still be soft deleted.
-- =============================================================================

ALTER TABLE raamaesha.capability_apis
    ADD CONSTRAINT ck_capability_apis_active_not_deleted
        CHECK (
            status <> 'active'
            OR deleted_at IS NULL
        );


-- =============================================================================
-- Prevent Active Capability Events From Being Soft Deleted
-- =============================================================================
--
-- Migration 023 models event lifecycle using:
--
--     status
--     deleted_at
--
-- Therefore the invalid state is:
--
--     status = 'active'
--     deleted_at IS NOT NULL
--
-- Historical non-active event versions may still be soft deleted.
-- =============================================================================

ALTER TABLE raamaesha.capability_events
    ADD CONSTRAINT ck_capability_events_active_not_deleted
        CHECK (
            status <> 'active'
            OR deleted_at IS NULL
        );


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_capability_apis_active_not_deleted
ON raamaesha.capability_apis IS
'Prevents an active capability API version from remaining discoverable as active after soft deletion.';


COMMENT ON CONSTRAINT
    ck_capability_events_active_not_deleted
ON raamaesha.capability_events IS
'Prevents an active capability event version from remaining discoverable as active after soft deletion.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;
