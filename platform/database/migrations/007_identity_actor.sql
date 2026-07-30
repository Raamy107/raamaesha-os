-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 007_identity_actor.sql
-- Module    : Identity Platform
--
-- Purpose:
--   Creates the universal Actor model used throughout RaamaEsha OS.
--
-- Responsibilities:
--   - Actor types
--   - Global actor identities
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENUM : actor_type
-- =============================================================================

CREATE TYPE public.actor_type AS ENUM
(
    'human',
    'organization',
    'team',
    'group',
    'branch',
    'ai_agent',
    'service_account',
    'device',
    'external_system'
);

COMMENT ON TYPE public.actor_type IS
'Defines the supported actor categories used by the RaamaEsha identity platform.';

-- =============================================================================
-- Actors
-- =============================================================================

CREATE TABLE raamaesha.actors
(
    id                      UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    actor_type              public.actor_type
        NOT NULL,

    code                    TEXT,

    display_name            TEXT
        NOT NULL,

    legal_name              TEXT,

    description             TEXT,

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

    CONSTRAINT pk_actors
        PRIMARY KEY (id),

    CONSTRAINT uq_actors_code
        UNIQUE (code),

    CONSTRAINT ck_actors_display_name_not_blank
        CHECK (length(trim(display_name)) > 0)
);

-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.actors IS
'Universal identity table representing every actor capable of interacting with the RaamaEsha platform.';

COMMENT ON COLUMN raamaesha.actors.id IS
'Globally unique identifier for the actor.';

COMMENT ON COLUMN raamaesha.actors.actor_type IS
'Classification of the actor.';

COMMENT ON COLUMN raamaesha.actors.code IS
'Optional unique business identifier for the actor.';

COMMENT ON COLUMN raamaesha.actors.display_name IS
'Primary display name of the actor.';

COMMENT ON COLUMN raamaesha.actors.legal_name IS
'Official legal name where applicable.';

COMMENT ON COLUMN raamaesha.actors.description IS
'Additional descriptive information about the actor.';

COMMENT ON COLUMN raamaesha.actors.is_active IS
'Indicates whether the actor is active.';

COMMENT ON COLUMN raamaesha.actors.created_at IS
'Timestamp when the actor was created.';

COMMENT ON COLUMN raamaesha.actors.updated_at IS
'Timestamp when the actor was last updated.';

COMMENT ON COLUMN raamaesha.actors.created_by IS
'Actor that created this record.';

COMMENT ON COLUMN raamaesha.actors.updated_by IS
'Actor that last updated this record.';

COMMENT ON COLUMN raamaesha.actors.deleted_at IS
'Soft deletion timestamp. NULL indicates an active record.';

-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_actors_actor_type
    ON raamaesha.actors (actor_type);

CREATE INDEX idx_actors_display_name
    ON raamaesha.actors (display_name);

CREATE INDEX idx_actors_is_active
    ON raamaesha.actors (is_active);

CREATE INDEX idx_actors_deleted_at
    ON raamaesha.actors (deleted_at);

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;