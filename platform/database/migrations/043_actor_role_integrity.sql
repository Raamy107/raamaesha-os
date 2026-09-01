-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 043_actor_role_integrity.sql
-- Module    : Identity & Authorization Integrity
--
-- Purpose:
--   Harden cross-table lifecycle integrity between actor role assignments
--   and their referenced roles.
--
-- Responsibilities:
--   - Prevent active actor-role assignments from referencing inactive roles
--   - Prevent active actor-role assignments from referencing soft-deleted roles
--   - Prevent roles from becoming inactive while active actor-role assignments exist
--   - Prevent roles from being soft deleted while active actor-role assignments exist
--   - Preserve historical actor-role assignments
--   - Preserve existing role lifecycle integrity
--   - Preserve existing temporal assignment integrity
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Actors remain the universal identity model
--   - Roles remain reusable authorization definitions
--   - Active assignments require current roles
--   - Historical assignments remain preserved
--   - Database-enforced lifecycle integrity
--   - Row locking serializes role lifecycle validation
--   - No authentication logic
--   - No permission definition logic
--   - No organization membership logic
--   - No runtime execution logic
--
-- Dependencies:
--   - 009_identity_roles.sql
--   - 012_actor_roles.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Actor Role Assignment -> Role Integrity
-- =============================================================================
--
-- An active actor-role assignment is valid only when its referenced role is:
--
--     is_active = TRUE
--     deleted_at IS NULL
--
-- The role row is locked before its lifecycle state is inspected.
--
-- This makes the role row the synchronization point for concurrent role
-- lifecycle and actor-role assignment changes.
--
-- Historical inactive assignments remain permitted.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_active_actor_role_role_integrity()
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
                'Active actor role assignment requires an existing role: role_id=%',
                NEW.role_id
                USING ERRCODE = '23514';
        END IF;

        IF role_is_active IS NOT TRUE
           OR role_deleted_at IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Active actor role assignment requires an active, non-deleted role: role_id=%, is_active=%, deleted_at=%',
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
-- Trigger : Actor Role Assignment -> Role
-- =============================================================================

CREATE TRIGGER trg_actor_roles_current_role_integrity
BEFORE INSERT OR UPDATE OF role_id, is_active, deleted_at
ON raamaesha.actor_roles
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_active_actor_role_role_integrity();


-- =============================================================================
-- Role -> Active Actor Role Assignment Integrity
-- =============================================================================
--
-- A role cannot become non-current while an active actor-role assignment
-- remains attached to it.
--
-- The role row is locked by the UPDATE itself and therefore acts as the
-- synchronization point for concurrent role lifecycle changes.
--
-- Actor-role assignments must be deactivated or historically closed before
-- the referenced role can be made inactive or soft deleted.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_role_current_actor_role_integrity()
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
            FROM raamaesha.actor_roles AS ar
            WHERE ar.role_id = NEW.id
              AND ar.is_active = TRUE
              AND ar.deleted_at IS NULL
        )
        THEN
            RAISE EXCEPTION
                'Role cannot become non-current while active actor role assignments exist: role_id=%',
                NEW.id
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Role -> Active Actor Role Assignment
-- =============================================================================

CREATE TRIGGER trg_roles_current_actor_role_integrity
BEFORE UPDATE OF is_active, deleted_at
ON raamaesha.roles
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_role_current_actor_role_integrity();


-- =============================================================================
-- Function Documentation
-- =============================================================================

COMMENT ON FUNCTION
    raamaesha.enforce_active_actor_role_role_integrity()
IS
'Ensures that an active, non-deleted actor-role assignment references an active, non-deleted role and locks the role row during validation.';


COMMENT ON FUNCTION
    raamaesha.enforce_role_current_actor_role_integrity()
IS
'Prevents a role from becoming inactive or soft deleted while active, non-deleted actor-role assignments remain attached.';


-- =============================================================================
-- Trigger Documentation
-- =============================================================================

COMMENT ON TRIGGER
    trg_actor_roles_current_role_integrity
ON raamaesha.actor_roles IS
'Enforces that current active actor-role assignments reference current active roles and serializes validation through the role row.';


COMMENT ON TRIGGER
    trg_roles_current_actor_role_integrity
ON raamaesha.roles IS
'Prevents roles from becoming non-current while active actor-role assignments remain attached.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 043
-- =============================================================================
