-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 041_organization_membership_role_role_integrity.sql
-- Module    : Identity & Organization Authorization Integrity
--
-- Purpose:
--   Harden cross-table lifecycle integrity between organization membership
--   role assignments and their referenced roles.
--
-- Responsibilities:
--   - Prevent active role assignments from referencing inactive roles
--   - Prevent active role assignments from referencing soft-deleted roles
--   - Prevent roles from becoming inactive while active assignments exist
--   - Prevent roles from being soft deleted while active assignments exist
--   - Preserve historical role assignments
--   - Preserve existing role-scope integrity
--   - Preserve forward-only migration discipline
--
-- Dependencies:
--   - 009_identity_roles.sql
--   - 036_organization_membership_roles.sql
--   - 037_organization_membership_role_integrity.sql
--   - 038_organization_membership_role_temporal_integrity.sql
--   - 039_organization_membership_role_current_integrity.sql
--   - 040_role_scope_reference_integrity.sql
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;


-- =============================================================================
-- Role Assignment -> Role Integrity
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_active_membership_role_role_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    role_is_active BOOLEAN;
    role_deleted_at TIMESTAMPTZ;
BEGIN

    IF NEW.is_active = TRUE
       AND NEW.deleted_at IS NULL
    THEN

        SELECT
            r.is_active,
            r.deleted_at
        INTO
            role_is_active,
            role_deleted_at
        FROM raamaesha.roles AS r
        WHERE r.id = NEW.role_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Active organization membership role assignment requires an existing role: role_id=%',
                NEW.role_id
                USING ERRCODE = '23514';
        END IF;

        IF role_is_active IS NOT TRUE
           OR role_deleted_at IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Active organization membership role assignment requires an active, non-deleted role: role_id=%, is_active=%, deleted_at=%',
                NEW.role_id,
                role_is_active,
                role_deleted_at
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Role Assignment -> Role
-- =============================================================================

CREATE TRIGGER trg_organization_membership_roles_current_role_integrity
BEFORE INSERT OR UPDATE OF role_id, is_active, deleted_at
ON raamaesha.organization_membership_roles
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_active_membership_role_role_integrity();


-- =============================================================================
-- Role -> Active Role Assignment Integrity
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_role_current_membership_role_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN

    IF (
        NEW.is_active = FALSE
        OR NEW.deleted_at IS NOT NULL
    )
    AND (
        OLD.is_active = TRUE
        AND OLD.deleted_at IS NULL
    )
    THEN

        IF EXISTS
        (
            SELECT 1
            FROM raamaesha.organization_membership_roles AS omr
            WHERE omr.role_id = NEW.id
              AND omr.is_active = TRUE
              AND omr.deleted_at IS NULL
        )
        THEN
            RAISE EXCEPTION
                'Role cannot become non-current while active organization membership role assignments exist: role_id=%',
                NEW.id
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Role -> Active Role Assignment
-- =============================================================================

CREATE TRIGGER trg_roles_current_membership_role_integrity
BEFORE UPDATE OF is_active, deleted_at
ON raamaesha.roles
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_role_current_membership_role_integrity();


-- =============================================================================
-- Function Documentation
-- =============================================================================

COMMENT ON FUNCTION
    raamaesha.enforce_active_membership_role_role_integrity()
IS
'Ensures that an active, non-deleted organization membership role assignment references an active, non-deleted role and locks the role row during validation.';


COMMENT ON FUNCTION
    raamaesha.enforce_role_current_membership_role_integrity()
IS
'Prevents a role from becoming inactive or soft deleted while active, non-deleted organization membership role assignments remain attached.';


-- =============================================================================
-- Trigger Documentation
-- =============================================================================

COMMENT ON TRIGGER
    trg_organization_membership_roles_current_role_integrity
ON raamaesha.organization_membership_roles IS
'Enforces that current active organization membership role assignments reference current active roles and serializes validation through the role row.';


COMMENT ON TRIGGER
    trg_roles_current_membership_role_integrity
ON raamaesha.roles IS
'Prevents roles from becoming non-current while active organization membership role assignments remain attached.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 041
-- =============================================================================