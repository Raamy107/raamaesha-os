-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 011_role_permissions.sql
-- Module    : Identity Platform
--
-- Purpose:
--   Assigns permissions to roles within the enterprise authorization engine.
--
-- Responsibilities:
--   - Role to Permission mapping
--   - Authorization assignments
--   - Permission lifecycle auditing
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Role Permissions
-- =============================================================================

CREATE TABLE raamaesha.role_permissions
(
    id                          UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    role_id                     UUID
        NOT NULL,

    permission_id               UUID
        NOT NULL,

    granted_at                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    is_active                   BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    created_at                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by                  UUID,

    updated_by                  UUID,

    deleted_at                  TIMESTAMPTZ,

    CONSTRAINT pk_role_permissions
        PRIMARY KEY (id),

    CONSTRAINT uq_role_permissions_role_permission
        UNIQUE (role_id, permission_id)
);

-- =============================================================================
-- Foreign Keys
-- =============================================================================

ALTER TABLE raamaesha.role_permissions
    ADD CONSTRAINT fk_role_permissions_role
        FOREIGN KEY (role_id)
        REFERENCES raamaesha.roles(id)
        ON DELETE CASCADE;

ALTER TABLE raamaesha.role_permissions
    ADD CONSTRAINT fk_role_permissions_permission
        FOREIGN KEY (permission_id)
        REFERENCES raamaesha.permissions(id)
        ON DELETE CASCADE;

ALTER TABLE raamaesha.role_permissions
    ADD CONSTRAINT fk_role_permissions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON DELETE SET NULL;

ALTER TABLE raamaesha.role_permissions
    ADD CONSTRAINT fk_role_permissions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON DELETE SET NULL;

-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.role_permissions IS
'Assigns permissions to roles within the enterprise authorization engine.';

COMMENT ON COLUMN raamaesha.role_permissions.id IS
'Globally unique identifier for the role-permission assignment.';

COMMENT ON COLUMN raamaesha.role_permissions.role_id IS
'Role receiving the permission.';

COMMENT ON COLUMN raamaesha.role_permissions.permission_id IS
'Permission assigned to the role.';

COMMENT ON COLUMN raamaesha.role_permissions.granted_at IS
'Timestamp when the permission became effective for the role.';

COMMENT ON COLUMN raamaesha.role_permissions.is_active IS
'Indicates whether the permission assignment is currently active.';

COMMENT ON COLUMN raamaesha.role_permissions.created_at IS
'Timestamp when the assignment record was created.';

COMMENT ON COLUMN raamaesha.role_permissions.updated_at IS
'Timestamp when the assignment record was last updated.';

COMMENT ON COLUMN raamaesha.role_permissions.created_by IS
'Actor that granted the permission.';

COMMENT ON COLUMN raamaesha.role_permissions.updated_by IS
'Actor that last modified the permission assignment.';

COMMENT ON COLUMN raamaesha.role_permissions.deleted_at IS
'Soft deletion timestamp. NULL indicates an active assignment.';

-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_role_permissions_role
    ON raamaesha.role_permissions(role_id);

CREATE INDEX idx_role_permissions_permission
    ON raamaesha.role_permissions(permission_id);

CREATE INDEX idx_role_permissions_active
    ON raamaesha.role_permissions(is_active);

CREATE INDEX idx_role_permissions_granted_at
    ON raamaesha.role_permissions(granted_at);

CREATE INDEX idx_role_permissions_deleted_at
    ON raamaesha.role_permissions(deleted_at);

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;