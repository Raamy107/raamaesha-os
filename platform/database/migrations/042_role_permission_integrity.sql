-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 042_role_permission_integrity.sql
-- Module    : Identity & Authorization Integrity
--
-- Purpose:
--   Harden cross-table lifecycle integrity between role-permission
--   assignments and their referenced roles and permissions.
--
-- Responsibilities:
--   - Prevent active role-permission assignments from referencing inactive roles
--   - Prevent active role-permission assignments from referencing soft-deleted roles
--   - Prevent active role-permission assignments from referencing inactive permissions
--   - Prevent active role-permission assignments from referencing soft-deleted permissions
--   - Prevent roles from becoming inactive while active permission assignments exist
--   - Prevent roles from being soft deleted while active permission assignments exist
--   - Prevent permissions from becoming inactive while active role assignments exist
--   - Prevent permissions from being soft deleted while active role assignments exist
--   - Preserve historical role-permission assignments
--   - Preserve existing role and permission lifecycle integrity
--   - Preserve forward-only migration discipline
--
-- Design Principles:
--   - Authorization relationships are database-enforced
--   - Active assignments require active referenced objects
--   - Historical assignments remain preserved
--   - Referenced object lifecycle is protected while active assignments exist
--   - No authentication logic
--   - No permission definition logic
--   - No runtime execution logic
--
-- Dependencies:
--   - 009_identity_roles.sql
--   - 010_identity_permissions.sql
--   - 011_role_permissions.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Role-Permission Assignment -> Role Integrity
-- =============================================================================
--
-- An active role-permission assignment is valid only when its referenced role
-- is active and has not been soft deleted.
--
-- The role row is locked before its lifecycle state is inspected.
-- This makes the role row the synchronization point for concurrent
-- role/role-permission lifecycle changes.
--
-- Historical inactive assignments remain permitted.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_active_role_permission_role_integrity()
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
                'Active role-permission assignment requires an existing role: role_id=%',
                NEW.role_id
                USING ERRCODE = '23514';
        END IF;

        IF role_is_active <> TRUE
           OR role_deleted_at IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Active role-permission assignment requires an active, non-deleted role: role_id=%, is_active=%, deleted_at=%',
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
-- Trigger : Role-Permission Assignment -> Role
-- =============================================================================

CREATE TRIGGER trg_role_permissions_current_role_integrity
BEFORE INSERT OR UPDATE OF role_id, is_active, deleted_at
ON raamaesha.role_permissions
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_active_role_permission_role_integrity();


-- =============================================================================
-- Role -> Active Permission Assignment Integrity
-- =============================================================================
--
-- A role cannot become inactive or soft deleted while an active,
-- non-deleted role-permission assignment remains attached to it.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_role_current_permission_integrity()
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
            FROM raamaesha.role_permissions AS rp
            WHERE rp.role_id = NEW.id
              AND rp.is_active = TRUE
              AND rp.deleted_at IS NULL
        )
        THEN
            RAISE EXCEPTION
                'Role cannot become inactive or soft deleted while active permission assignments exist: role_id=%',
                NEW.id
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Role -> Active Permission Assignment
-- =============================================================================

CREATE TRIGGER trg_roles_current_permission_integrity
BEFORE UPDATE OF is_active, deleted_at
ON raamaesha.roles
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_role_current_permission_integrity();


-- =============================================================================
-- Role-Permission Assignment -> Permission Integrity
-- =============================================================================
--
-- An active role-permission assignment is valid only when its referenced
-- permission is active and has not been soft deleted.
--
-- The permission row is locked before its lifecycle state is inspected.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_active_role_permission_permission_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    permission_is_active BOOLEAN;
    permission_deleted_at TIMESTAMPTZ;
BEGIN

    IF NEW.is_active = TRUE
       AND NEW.deleted_at IS NULL
    THEN

        SELECT
            p.is_active,
            p.deleted_at
        INTO
            permission_is_active,
            permission_deleted_at
        FROM raamaesha.permissions AS p
        WHERE p.id = NEW.permission_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Active role-permission assignment requires an existing permission: permission_id=%',
                NEW.permission_id
                USING ERRCODE = '23514';
        END IF;

        IF permission_is_active <> TRUE
           OR permission_deleted_at IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Active role-permission assignment requires an active, non-deleted permission: permission_id=%, is_active=%, deleted_at=%',
                NEW.permission_id,
                permission_is_active,
                permission_deleted_at
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Role-Permission Assignment -> Permission
-- =============================================================================

CREATE TRIGGER trg_role_permissions_current_permission_integrity
BEFORE INSERT OR UPDATE OF permission_id, is_active, deleted_at
ON raamaesha.role_permissions
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_active_role_permission_permission_integrity();


-- =============================================================================
-- Permission -> Active Role Assignment Integrity
-- =============================================================================
--
-- A permission cannot become inactive or soft deleted while an active,
-- non-deleted role-permission assignment remains attached to it.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_permission_current_role_integrity()
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
            FROM raamaesha.role_permissions AS rp
            WHERE rp.permission_id = NEW.id
              AND rp.is_active = TRUE
              AND rp.deleted_at IS NULL
        )
        THEN
            RAISE EXCEPTION
                'Permission cannot become inactive or soft deleted while active role assignments exist: permission_id=%',
                NEW.id
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Permission -> Active Role Assignment
-- =============================================================================

CREATE TRIGGER trg_permissions_current_role_integrity
BEFORE UPDATE OF is_active, deleted_at
ON raamaesha.permissions
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_permission_current_role_integrity();


-- =============================================================================
-- Function Documentation
-- =============================================================================

COMMENT ON FUNCTION
    raamaesha.enforce_active_role_permission_role_integrity()
IS
'Ensures that an active, non-deleted role-permission assignment references an active, non-deleted role and locks the role row during validation.';


COMMENT ON FUNCTION
    raamaesha.enforce_role_current_permission_integrity()
IS
'Prevents a role from becoming inactive or soft deleted while active, non-deleted permission assignments remain attached.';


COMMENT ON FUNCTION
    raamaesha.enforce_active_role_permission_permission_integrity()
IS
'Ensures that an active, non-deleted role-permission assignment references an active, non-deleted permission and locks the permission row during validation.';


COMMENT ON FUNCTION
    raamaesha.enforce_permission_current_role_integrity()
IS
'Prevents a permission from becoming inactive or soft deleted while active, non-deleted role assignments remain attached.';


-- =============================================================================
-- Trigger Documentation
-- =============================================================================

COMMENT ON TRIGGER
    trg_role_permissions_current_role_integrity
ON raamaesha.role_permissions IS
'Enforces that current active role-permission assignments reference current active roles and serializes validation through the role row.';


COMMENT ON TRIGGER
    trg_roles_current_permission_integrity
ON raamaesha.roles IS
'Prevents roles from becoming inactive or soft deleted while active permission assignments remain attached.';


COMMENT ON TRIGGER
    trg_role_permissions_current_permission_integrity
ON raamaesha.role_permissions IS
'Enforces that current active role-permission assignments reference current active permissions and serializes validation through the permission row.';


COMMENT ON TRIGGER
    trg_permissions_current_role_integrity
ON raamaesha.permissions IS
'Prevents permissions from becoming inactive or soft deleted while active role assignments remain attached.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 042
-- =============================================================================