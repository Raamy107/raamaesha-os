-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 037_organization_membership_role_integrity.sql
-- Module    : Identity & Organization Authorization Integrity
--
-- Purpose:
--   Harden lifecycle integrity of organization membership role assignments
--   created by Migration 036.
--
-- Responsibilities:
--   - Prevent active membership-role assignments from being soft deleted
--   - Preserve historical role assignments
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Database-enforced lifecycle integrity
--   - Soft deletion remains available for historical records
--   - Active role assignments must remain discoverable
--   - Existing organization role-scope integrity remains enforced by Migration 036
--   - Existing temporal validity remains enforced by Migration 036
--   - Existing uniqueness semantics remain enforced by Migration 036
--   - No authentication logic
--   - No permission definition logic
--   - No runtime execution logic
--
-- Dependencies:
--   - 036_organization_membership_roles.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Prevent Active Membership Role Assignments From Being Soft Deleted
-- =============================================================================
--
-- Migration 036 models assignment lifecycle using:
--
--     is_active
--     deleted_at
--
-- The invalid state is:
--
--     is_active = TRUE
--     deleted_at IS NOT NULL
--
-- Historical inactive assignments may still be soft deleted.
-- =============================================================================

ALTER TABLE raamaesha.organization_membership_roles
    ADD CONSTRAINT ck_organization_membership_roles_active_not_deleted
        CHECK (
            is_active = FALSE
            OR deleted_at IS NULL
        );


-- =============================================================================
-- Constraint Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_organization_membership_roles_active_not_deleted
ON raamaesha.organization_membership_roles IS
'Prevents an active organization membership role assignment from remaining active after soft deletion.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 037
-- =============================================================================
