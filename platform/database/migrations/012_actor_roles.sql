-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 012_actor_roles.sql
-- Module    : Identity Platform
--
-- Purpose:
--   Assigns roles to actors within the enterprise authorization engine.
--
-- Responsibilities:
--   - Actor to Role assignments
--   - Temporal role assignments
--   - Role lifecycle management
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Actor Roles
-- =============================================================================

CREATE TABLE raamaesha.actor_roles
(
    id                          UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    actor_id                    UUID
        NOT NULL,

    role_id                     UUID
        NOT NULL,

    valid_from                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    valid_to                    TIMESTAMPTZ,

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

    CONSTRAINT pk_actor_roles
        PRIMARY KEY (id),

    CONSTRAINT uq_actor_roles_actor_role_valid_from
        UNIQUE
        (
            actor_id,
            role_id,
            valid_from
        ),

    CONSTRAINT chk_actor_roles_valid_period
        CHECK
        (
            valid_to IS NULL
            OR valid_to >= valid_from
        )
);

-- =============================================================================
-- Foreign Keys
-- =============================================================================

ALTER TABLE raamaesha.actor_roles
    ADD CONSTRAINT fk_actor_roles_actor
        FOREIGN KEY (actor_id)
        REFERENCES raamaesha.actors(id)
        ON DELETE CASCADE;

ALTER TABLE raamaesha.actor_roles
    ADD CONSTRAINT fk_actor_roles_role
        FOREIGN KEY (role_id)
        REFERENCES raamaesha.roles(id)
        ON DELETE CASCADE;

ALTER TABLE raamaesha.actor_roles
    ADD CONSTRAINT fk_actor_roles_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON DELETE SET NULL;

ALTER TABLE raamaesha.actor_roles
    ADD CONSTRAINT fk_actor_roles_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON DELETE SET NULL;

-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_actor_roles_actor
    ON raamaesha.actor_roles(actor_id);

CREATE INDEX idx_actor_roles_role
    ON raamaesha.actor_roles(role_id);

CREATE INDEX idx_actor_roles_active
    ON raamaesha.actor_roles(is_active);

CREATE INDEX idx_actor_roles_valid_from
    ON raamaesha.actor_roles(valid_from);

CREATE INDEX idx_actor_roles_valid_to
    ON raamaesha.actor_roles(valid_to);

CREATE INDEX idx_actor_roles_deleted_at
    ON raamaesha.actor_roles(deleted_at);

-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.actor_roles IS
'Assigns roles to actors within the enterprise authorization engine.';

COMMENT ON COLUMN raamaesha.actor_roles.id IS
'Globally unique identifier for the actor-role assignment.';

COMMENT ON COLUMN raamaesha.actor_roles.actor_id IS
'Actor receiving the role assignment.';

COMMENT ON COLUMN raamaesha.actor_roles.role_id IS
'Role assigned to the actor.';

COMMENT ON COLUMN raamaesha.actor_roles.valid_from IS
'Timestamp when the role assignment becomes effective.';

COMMENT ON COLUMN raamaesha.actor_roles.valid_to IS
'Timestamp when the role assignment expires. NULL indicates no expiration.';

COMMENT ON COLUMN raamaesha.actor_roles.is_active IS
'Indicates whether the role assignment is currently active.';

COMMENT ON COLUMN raamaesha.actor_roles.created_at IS
'Timestamp when the assignment record was created.';

COMMENT ON COLUMN raamaesha.actor_roles.updated_at IS
'Timestamp when the assignment record was last updated.';

COMMENT ON COLUMN raamaesha.actor_roles.created_by IS
'Actor that created the role assignment.';

COMMENT ON COLUMN raamaesha.actor_roles.updated_by IS
'Actor that last modified the role assignment.';

COMMENT ON COLUMN raamaesha.actor_roles.deleted_at IS
'Soft deletion timestamp. NULL indicates an active assignment.';

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;