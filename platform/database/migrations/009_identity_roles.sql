-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 009_identity_roles.sql
-- Module    : Identity Platform
--
-- Purpose:
--   Creates the universal roles model.
--
-- Responsibilities:
--   - Role scopes
--   - Platform roles
--   - Organization roles
--   - Branch roles
--   - Team roles
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENUM : role_scope
-- =============================================================================

CREATE TYPE public.role_scope AS ENUM
(
    'platform',
    'organization',
    'branch',
    'team',
    'project'
);

COMMENT ON TYPE public.role_scope IS
'Defines the scope at which a role is applicable within the platform.';

-- =============================================================================
-- Roles
-- =============================================================================

CREATE TABLE raamaesha.roles
(
    id                      UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    code                    TEXT
        NOT NULL,

    display_name            TEXT
        NOT NULL,

    description             TEXT,

    scope                   public.role_scope
        NOT NULL,

    is_system               BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    is_active               BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    created_at              TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at              TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by              UUID,

    updated_by              UUID,

    deleted_at              TIMESTAMPTZ,

    CONSTRAINT pk_roles
        PRIMARY KEY (id),

    CONSTRAINT uq_roles_code_scope
        UNIQUE (code, scope),

    CONSTRAINT ck_roles_display_name_not_blank
        CHECK (length(trim(display_name)) > 0)
);

-- =============================================================================
-- Foreign Keys
-- =============================================================================

ALTER TABLE raamaesha.roles
    ADD CONSTRAINT fk_roles_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL;

ALTER TABLE raamaesha.roles
    ADD CONSTRAINT fk_roles_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL;

-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.roles IS
'Stores platform and organization roles used for authorization.';

COMMENT ON COLUMN raamaesha.roles.id IS
'Globally unique identifier for the role.';

COMMENT ON COLUMN raamaesha.roles.code IS
'Unique role code within its scope.';

COMMENT ON COLUMN raamaesha.roles.display_name IS
'Human-readable role name.';

COMMENT ON COLUMN raamaesha.roles.description IS
'Optional description of the role.';

COMMENT ON COLUMN raamaesha.roles.scope IS
'Defines the scope where the role is applicable.';

COMMENT ON COLUMN raamaesha.roles.is_system IS
'Indicates whether this is a protected system-defined role.';

COMMENT ON COLUMN raamaesha.roles.is_active IS
'Indicates whether the role is currently active.';

COMMENT ON COLUMN raamaesha.roles.created_at IS
'Timestamp when the role was created.';

COMMENT ON COLUMN raamaesha.roles.updated_at IS
'Timestamp when the role was last updated.';

COMMENT ON COLUMN raamaesha.roles.created_by IS
'Actor that created the role.';

COMMENT ON COLUMN raamaesha.roles.updated_by IS
'Actor that last updated the role.';

COMMENT ON COLUMN raamaesha.roles.deleted_at IS
'Soft deletion timestamp. NULL indicates an active role.';

-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_roles_scope
    ON raamaesha.roles (scope);

CREATE INDEX idx_roles_active
    ON raamaesha.roles (is_active);

CREATE INDEX idx_roles_system
    ON raamaesha.roles (is_system);

CREATE INDEX idx_roles_deleted_at
    ON raamaesha.roles (deleted_at);

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;