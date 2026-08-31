-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 038_organization_membership_role_temporal_integrity.sql
-- Module    : Identity & Organization Authorization Integrity
--
-- Purpose:
--   Harden temporal lifecycle integrity of organization membership role
--   assignments created by Migration 036.
--
-- Responsibilities:
--   - Prevent ended role assignments from remaining active
--   - Preserve historical role assignments
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Database-enforced temporal integrity
--   - Historical assignments remain preserved
--   - Active assignments may remain open-ended
--   - No time-dependent CHECK constraints
--   - No authentication logic
--   - No permission definition logic
--   - No runtime execution logic
--
-- Dependencies:
--   - 036_organization_membership_roles.sql
--   - 037_organization_membership_role_integrity.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Prevent Ended Role Assignments From Remaining Active
-- =============================================================================

ALTER TABLE raamaesha.organization_membership_roles
    ADD CONSTRAINT ck_organization_membership_roles_ended_not_active
        CHECK (
            valid_to IS NULL
            OR is_active = FALSE
        );


-- =============================================================================
-- Constraint Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_organization_membership_roles_ended_not_active
ON raamaesha.organization_membership_roles IS
'Prevents an organization membership role assignment with an explicit valid_to timestamp from remaining active.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 038
-- =============================================================================