/*
===============================================================================
RaamaEsha OS Founder Edition
Migration : 010_identity_permissions.sql
Module    : Identity Platform

Purpose:
    Creates the enterprise permission catalog used by the
    RaamaEsha OS authorization engine.

Responsibilities:
    - Permission categories
    - Permission actions
    - Permission risk levels
    - Global permission catalog

PostgreSQL : 17+
===============================================================================
*/

BEGIN;

-- ============================================================================
-- ENUM : Permission Category
-- ============================================================================

CREATE TYPE public.permission_category AS ENUM
(
    'identity',
    'platform',
    'crm',
    'sales',
    'inventory',
    'finance',
    'hr',
    'ai',
    'integration',
    'reporting'
);

COMMENT ON TYPE public.permission_category IS
'Logical business category for enterprise permissions.';

-- ============================================================================
-- ENUM : Permission Action
-- ============================================================================

CREATE TYPE public.permission_action AS ENUM
(
    'create',
    'read',
    'update',
    'delete',
    'assign',
    'approve',
    'reject',
    'execute',
    'manage',
    'export',
    'import'
);

COMMENT ON TYPE public.permission_action IS
'Supported enterprise permission actions.';

-- ============================================================================
-- ENUM : Permission Risk Level
-- ============================================================================

CREATE TYPE public.permission_risk_level AS ENUM
(
    'low',
    'medium',
    'high',
    'critical'
);

COMMENT ON TYPE public.permission_risk_level IS
'Risk classification for enterprise permissions.';

-- ============================================================================
-- Permissions
-- ============================================================================

CREATE TABLE raamaesha.permissions
(
    id                          UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    code                        CITEXT
        NOT NULL,

    category                    public.permission_category
        NOT NULL,

    module                      TEXT
        NOT NULL,

    resource                    TEXT
        NOT NULL,

    action                      public.permission_action
        NOT NULL,

    display_name                TEXT
        NOT NULL,

    description                 TEXT,

    risk_level                  public.permission_risk_level
        NOT NULL
        DEFAULT 'low',

    sort_order                  INTEGER
        NOT NULL
        DEFAULT 100,

    is_system                   BOOLEAN
        NOT NULL
        DEFAULT FALSE,

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

    CONSTRAINT pk_permissions
        PRIMARY KEY (id),

    CONSTRAINT uq_permissions_code
        UNIQUE (code),

    CONSTRAINT ck_permissions_code
        CHECK (
            code ~ '^[a-z0-9]+(\.[a-z0-9_]+)+$'
        ),

    CONSTRAINT ck_permissions_sort_order
        CHECK (sort_order >= 0)
);

-- ============================================================================
-- Foreign Keys
-- ============================================================================

ALTER TABLE raamaesha.permissions
    ADD CONSTRAINT fk_permissions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL;

ALTER TABLE raamaesha.permissions
    ADD CONSTRAINT fk_permissions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL;

-- ============================================================================
-- Secondary Indexes
-- ============================================================================

CREATE INDEX idx_permissions_category
    ON raamaesha.permissions (category);

CREATE INDEX idx_permissions_module
    ON raamaesha.permissions (module);

CREATE INDEX idx_permissions_resource
    ON raamaesha.permissions (resource);

CREATE INDEX idx_permissions_action
    ON raamaesha.permissions (action);

CREATE INDEX idx_permissions_risk_level
    ON raamaesha.permissions (risk_level);

CREATE INDEX idx_permissions_is_system
    ON raamaesha.permissions (is_system);

CREATE INDEX idx_permissions_is_active
    ON raamaesha.permissions (is_active);

CREATE INDEX idx_permissions_deleted_at
    ON raamaesha.permissions (deleted_at);

CREATE UNIQUE INDEX ux_permissions_module_resource_action
    ON raamaesha.permissions
    (
        module,
        resource,
        action
    );

-- ============================================================================
-- Table Documentation
-- ============================================================================

COMMENT ON TABLE raamaesha.permissions IS
'Enterprise permission catalog for the RaamaEsha OS authorization engine.';

COMMENT ON COLUMN raamaesha.permissions.id IS
'Globally unique identifier for the permission.';

COMMENT ON COLUMN raamaesha.permissions.code IS
'Globally unique permission code.';

COMMENT ON COLUMN raamaesha.permissions.category IS
'Business category to which the permission belongs.';

COMMENT ON COLUMN raamaesha.permissions.module IS
'Application module that owns the permission.';

COMMENT ON COLUMN raamaesha.permissions.resource IS
'Protected business resource.';

COMMENT ON COLUMN raamaesha.permissions.action IS
'Operation permitted on the resource.';

COMMENT ON COLUMN raamaesha.permissions.display_name IS
'Human-readable permission name.';

COMMENT ON COLUMN raamaesha.permissions.description IS
'Optional description of the permission.';

COMMENT ON COLUMN raamaesha.permissions.risk_level IS
'Security risk classification associated with the permission.';

COMMENT ON COLUMN raamaesha.permissions.sort_order IS
'Display order used by administrative interfaces.';

COMMENT ON COLUMN raamaesha.permissions.is_system IS
'Indicates whether this is a protected system permission.';

COMMENT ON COLUMN raamaesha.permissions.is_active IS
'Indicates whether the permission is currently active.';

COMMENT ON COLUMN raamaesha.permissions.created_at IS
'Timestamp when the permission was created.';

COMMENT ON COLUMN raamaesha.permissions.updated_at IS
'Timestamp when the permission was last updated.';

COMMENT ON COLUMN raamaesha.permissions.created_by IS
'Actor that created the permission.';

COMMENT ON COLUMN raamaesha.permissions.updated_by IS
'Actor that last updated the permission.';

COMMENT ON COLUMN raamaesha.permissions.deleted_at IS
'Soft deletion timestamp. NULL indicates an active permission.';

-- ============================================================================
-- Migration Complete
-- ============================================================================

COMMIT;