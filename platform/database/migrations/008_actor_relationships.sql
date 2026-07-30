-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 008_actor_relationships.sql
-- Module    : Identity Platform
--
-- Purpose:
--   Creates universal relationships between actors.
--
-- Responsibilities:
--   - Relationship types
--   - Actor-to-actor relationships
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENUM : actor_relationship_type
-- =============================================================================

CREATE TYPE public.actor_relationship_type AS ENUM
(
    'belongs_to',
    'member_of',
    'works_for',
    'manages',
    'owns',
    'reports_to',
    'serves',
    'controls',
    'connected_to'
);

COMMENT ON TYPE public.actor_relationship_type IS
'Defines supported relationship types between actors.';

-- =============================================================================
-- Actor Relationships
-- =============================================================================

CREATE TABLE raamaesha.actor_relationships
(
    id                          UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    from_actor_id               UUID
        NOT NULL,

    relationship_type           public.actor_relationship_type
        NOT NULL,

    to_actor_id                 UUID
        NOT NULL,

    is_active                   BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    valid_from                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    valid_to                    TIMESTAMPTZ,

    created_at                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by                  UUID,

    updated_by                  UUID,

    deleted_at                  TIMESTAMPTZ,

    CONSTRAINT pk_actor_relationships
        PRIMARY KEY (id),

    CONSTRAINT fk_actor_relationships_from_actor
        FOREIGN KEY (from_actor_id)
        REFERENCES raamaesha.actors(id)
        ON DELETE CASCADE,

    CONSTRAINT fk_actor_relationships_to_actor
        FOREIGN KEY (to_actor_id)
        REFERENCES raamaesha.actors(id)
        ON DELETE CASCADE,

    CONSTRAINT ck_actor_relationships_not_self
        CHECK (from_actor_id <> to_actor_id),

    CONSTRAINT uq_actor_relationships
        UNIQUE
        (
            from_actor_id,
            to_actor_id,
            relationship_type,
            valid_from
        )
);

-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.actor_relationships IS
'Stores relationships between actors in the RaamaEsha identity platform.';

COMMENT ON COLUMN raamaesha.actor_relationships.id IS
'Globally unique identifier for the relationship.';

COMMENT ON COLUMN raamaesha.actor_relationships.from_actor_id IS
'Source actor in the relationship.';

COMMENT ON COLUMN raamaesha.actor_relationships.relationship_type IS
'Defines how two actors are related.';

COMMENT ON COLUMN raamaesha.actor_relationships.to_actor_id IS
'Target actor in the relationship.';

COMMENT ON COLUMN raamaesha.actor_relationships.is_active IS
'Indicates whether the relationship is currently active.';

COMMENT ON COLUMN raamaesha.actor_relationships.valid_from IS
'Timestamp from which the relationship is valid.';

COMMENT ON COLUMN raamaesha.actor_relationships.valid_to IS
'Timestamp until which the relationship remains valid.';

COMMENT ON COLUMN raamaesha.actor_relationships.created_at IS
'Timestamp when the relationship was created.';

COMMENT ON COLUMN raamaesha.actor_relationships.updated_at IS
'Timestamp when the relationship was last updated.';

COMMENT ON COLUMN raamaesha.actor_relationships.created_by IS
'Actor that created this relationship.';

COMMENT ON COLUMN raamaesha.actor_relationships.updated_by IS
'Actor that last updated this relationship.';

COMMENT ON COLUMN raamaesha.actor_relationships.deleted_at IS
'Soft deletion timestamp. NULL indicates an active relationship.';

-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_actor_relationships_from_actor
    ON raamaesha.actor_relationships (from_actor_id);

CREATE INDEX idx_actor_relationships_to_actor
    ON raamaesha.actor_relationships (to_actor_id);

CREATE INDEX idx_actor_relationships_type
    ON raamaesha.actor_relationships (relationship_type);

CREATE INDEX idx_actor_relationships_active
    ON raamaesha.actor_relationships (is_active);

CREATE INDEX idx_actor_relationships_valid_from
    ON raamaesha.actor_relationships (valid_from);

CREATE INDEX idx_actor_relationships_valid_to
    ON raamaesha.actor_relationships (valid_to);

CREATE INDEX idx_actor_relationships_deleted_at
    ON raamaesha.actor_relationships (deleted_at);

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;