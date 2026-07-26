-- ============================================================
-- RaamaEsha OS Founder Edition v1.0
-- Sprint 005 : Identity Platform V2
-- Migration : 009_identity_roles.sql
-- Author : RaamaEsha Engineering
-- ============================================================

BEGIN;

-- ============================================================
-- Purpose
-- ============================================================

-- Creates the universal Roles model.
--
-- Every Actor can have one or more Roles.
--
-- Examples:
--
-- Human ------> Founder
-- Human ------> Doctor
-- Human ------> HR Manager
-- AI Agent ---> Receptionist
-- AI Agent ---> Sales Assistant
-- Branch -----> Warehouse
--
-- Permissions will be assigned to Roles,
-- not directly to Actors.
-- ============================================================
-- Role Types
-- ============================================================

CREATE TYPE public.role_scope AS ENUM
(
    'platform',
    'organization',
    'branch',
    'team',
    'project'
);

-- ==============================================================
-- Roles
-- ==============================================================

CREATE TABLE raamaesha.roles
(    id              UUID
                    PRIMARY KEY
                    DEFAULT gen_random_uuid(),

 code            TEXT
                 NOT NULL,
                        
 display_name    TEXT
                 NOT NULL,
 description     TEXT,
 scope           public.role_scope
                 NOT NULL,
 is_system BOOLEAN NOT NULL DEFAULT FALSE,
 is_active BOOLEAN NOT NULL DEFAULT TRUE,
 

    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            created_by      UUID,
                updated_by      UUID
                );
-- ==============================================
-- Constraints
-- ============================================================
ALTER TABLE raamaesha.roles
    ADD CONSTRAINT uq_roles_code_scope
    UNIQUE (code, scope);
    -- ============================================================
-- Foreign Keys
-- ============================================================

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
        -- ==========================================================
-- Indexes
-- ==========================================================
CREATE INDEX idx_roles_scope
ON raamaesha.roles (scope);

CREATE INDEX idx_roles_active
ON raamaesha.roles (is_active);

CREATE INDEX idx_roles_system
ON raamaesha.roles (is_system);
-- ==========================================================
-- Comments
-- ==========================================================
COMMENT ON TABLE raamaesha.roles
IS 'Stores platform and tenant roles.';

COMMENT ON COLUMN raamaesha.roles.code
IS 'Unique role code within its scope.';

COMMENT ON COLUMN raamaesha.roles.display_name
IS 'Human-readable role name.';

COMMENT ON COLUMN raamaesha.roles.description
IS 'Optional description of the role.';

COMMENT ON COLUMN raamaesha.roles.scope
IS 'Defines whether the role belongs to the platform or a tenant.';

COMMENT ON COLUMN raamaesha.roles.is_system
IS 'Indicates whether the role is a protected system role.';

COMMENT ON COLUMN raamaesha.roles.is_active
IS 'Determines whether the role is currently active.';
COMMENT ON COLUMN raamaesha.roles.created_at
IS 'Timestamp when the role was created.';

COMMENT ON COLUMN raamaesha.roles.updated_at
IS 'Timestamp when the role was last updated.';

COMMENT ON COLUMN raamaesha.roles.created_by
IS 'Actor who created the role.';

COMMENT ON COLUMN raamaesha.roles.updated_by
IS 'Actor who last updated the role.';
COMMIT;