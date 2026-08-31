-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 039_organization_membership_role_current_integrity.sql
-- Module    : Identity & Organization Authorization Integrity
--
-- Purpose:
--   Enforce cross-table lifecycle integrity between organization memberships
--   and their current organization membership-role assignments.
--
-- Responsibilities:
--   - Prevent active role assignments from belonging to non-current memberships
--   - Prevent memberships from becoming non-current while active role
--     assignments still exist
--   - Preserve historical membership and role records
--   - Serialize membership/role lifecycle changes through membership-row locks
--   - Enforce authorization lifecycle integrity at the database boundary
--
-- Design Principles:
--   - Membership establishes tenant participation
--   - Role assignment depends on valid membership participation
--   - Active role assignments require active memberships
--   - Historical records remain preserved
--   - Cross-table lifecycle integrity is database enforced
--   - Membership is the synchronization authority for its role assignments
--   - No authentication logic
--   - No permission definition logic
--   - No runtime execution logic
--
-- Dependencies:
--   - 035_organization_memberships.sql
--   - 036_organization_membership_roles.sql
--   - 037_organization_membership_role_integrity.sql
--   - 038_organization_membership_role_temporal_integrity.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Role Assignment -> Membership Integrity
-- =============================================================================
--
-- An active role assignment is valid only when its membership is:
--
--     status = 'active'
--     deleted_at IS NULL
--
-- The membership row is locked before its lifecycle state is inspected.
-- This makes the membership row the synchronization point for concurrent
-- membership/role lifecycle changes.
--
-- Historical inactive role assignments remain permitted.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_active_membership_role_membership_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    membership_status public.organization_membership_status;
    membership_deleted_at TIMESTAMPTZ;
BEGIN

    IF NEW.is_active = TRUE
       AND NEW.deleted_at IS NULL
    THEN

        SELECT
            om.status,
            om.deleted_at
        INTO
            membership_status,
            membership_deleted_at
        FROM raamaesha.organization_memberships AS om
        WHERE om.id = NEW.membership_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Active organization membership role assignment requires an existing membership: membership_id=%',
                NEW.membership_id
                USING ERRCODE = '23514';
        END IF;

        IF membership_status <> 'active'
           OR membership_deleted_at IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Active organization membership role assignment requires an active, non-deleted membership: membership_id=%, status=%, deleted_at=%',
                NEW.membership_id,
                membership_status,
                membership_deleted_at
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Role Assignment -> Membership
-- =============================================================================

CREATE TRIGGER trg_organization_membership_roles_current_membership_integrity
BEFORE INSERT OR UPDATE OF membership_id, is_active, deleted_at
ON raamaesha.organization_membership_roles
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_active_membership_role_membership_integrity();


-- =============================================================================
-- Membership -> Active Role Assignment Integrity
-- =============================================================================
--
-- A membership cannot become non-current while an active role assignment
-- remains attached to it.
--
-- The membership row is already being modified by the current transaction,
-- therefore PostgreSQL provides the required row-level serialization point
-- for concurrent lifecycle changes involving that membership.
--
-- The role assignment must be deactivated before the membership lifecycle
-- can be ended or the membership can be soft deleted.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_membership_current_role_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN

    IF (
        NEW.status <> 'active'
        OR NEW.deleted_at IS NOT NULL
    )
    AND (
        OLD.status = 'active'
        AND OLD.deleted_at IS NULL
    )
    THEN

        IF EXISTS
        (
            SELECT 1
            FROM raamaesha.organization_membership_roles AS omr
            WHERE omr.membership_id = NEW.id
              AND omr.is_active = TRUE
              AND omr.deleted_at IS NULL
        )
        THEN
            RAISE EXCEPTION
                'Organization membership cannot become non-current while active role assignments exist: membership_id=%',
                NEW.id
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Membership -> Active Role Assignment
-- =============================================================================

CREATE TRIGGER trg_organization_memberships_current_role_integrity
BEFORE UPDATE OF status, deleted_at
ON raamaesha.organization_memberships
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_membership_current_role_integrity();


-- =============================================================================
-- Function Documentation
-- =============================================================================

COMMENT ON FUNCTION
    raamaesha.enforce_active_membership_role_membership_integrity()
IS
'Ensures that an active, non-deleted organization membership role assignment belongs to an active, non-deleted organization membership and locks the membership row during validation.';


COMMENT ON FUNCTION
    raamaesha.enforce_membership_current_role_integrity()
IS
'Prevents an organization membership from becoming non-current while active, non-deleted role assignments remain attached.';


-- =============================================================================
-- Trigger Documentation
-- =============================================================================

COMMENT ON TRIGGER
    trg_organization_membership_roles_current_membership_integrity
ON raamaesha.organization_membership_roles IS
'Enforces that current active role assignments belong to current active memberships and serializes validation through the membership row.';


COMMENT ON TRIGGER
    trg_organization_memberships_current_role_integrity
ON raamaesha.organization_memberships IS
'Prevents memberships from becoming non-current while active role assignments remain attached.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 039
-- =============================================================================