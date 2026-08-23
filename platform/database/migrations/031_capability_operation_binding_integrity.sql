-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 031_capability_operation_binding_integrity.sql
-- Module    : Capability Operation Binding Integrity
--
-- Purpose:
--   Harden lifecycle integrity of capability operation bindings created
--   by Migration 024.
--
-- Responsibilities:
--   - Prevent active capability operation bindings from being soft deleted
--   - Preserve historical binding versions
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Correct historical schema through a forward-only migration
--   - Database-enforced lifecycle integrity
--   - Soft deletion remains available for historical records
--   - Active bindings must remain discoverable
--   - Existing ownership integrity remains enforced by Migration 025
--   - Existing uniqueness semantics remain enforced by Migration 025
--   - No execution logic
--   - No workflow execution
--   - No worker scheduling
--   - No queue management
--   - No runtime orchestration
--   - No plaintext secrets
--
-- Dependencies:
--   - 024_capability_operation_bindings.sql
--   - 025_capability_binding_integrity.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Prevent Active Capability Operation Bindings From Being Soft Deleted
-- =============================================================================
--
-- Migration 024 models binding lifecycle using:
--
--     status
--     deleted_at
--
-- Migration 025 strengthens binding ownership and uniqueness semantics but
-- does not explicitly prevent an active binding from being soft deleted.
--
-- Therefore the invalid state is:
--
--     status = 'active'
--     deleted_at IS NOT NULL
--
-- Historical non-active binding versions may still be soft deleted.
--
-- This constraint completes lifecycle integrity for capability operation
-- bindings without changing their existing ownership or uniqueness rules.
-- =============================================================================

ALTER TABLE raamaesha.capability_operation_bindings
    ADD CONSTRAINT ck_capability_operation_bindings_active_not_deleted
        CHECK (
            status <> 'active'
            OR deleted_at IS NULL
        );


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_capability_operation_bindings_active_not_deleted
ON raamaesha.capability_operation_bindings IS
'Prevents an active capability operation binding from remaining active after soft deletion.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;