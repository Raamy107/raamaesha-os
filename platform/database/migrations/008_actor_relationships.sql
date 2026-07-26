-- ============================================================
-- RaamaEsha OS Founder Edition
-- Sprint 005 : Identity Platform V2
-- Migration : 008_actor_relationships.sql
--
-- Purpose
-- -------
-- Universal relationships between Actors.
--
-- Everything in the platform connects through Actors.
--
-- Human -> Organization
-- Human -> Team
-- Branch -> Organization
-- AI Agent -> Team
-- Device -> Branch
-- External System -> Organization
-- ============================================================

BEGIN;
-- ============================================================
-- Relationship Types
-- ============================================================

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
-- ============================================================
-- Actor Relationships
-- ============================================================

CREATE TABLE raamaesha.actor_relationships
(
    id                          UUID PRIMARY KEY
                                DEFAULT gen_random_uuid(),

    from_actor_id               UUID
                                NOT NULL
                                REFERENCES raamaesha.actors(id),

    relationship_type           public.actor_relationship_type
                                NOT NULL,

    to_actor_id                 UUID
                                NOT NULL
                                REFERENCES raamaesha.actors(id),

    is_active                   BOOLEAN
                                NOT NULL
                                DEFAULT TRUE,

    valid_from                  TIMESTAMPTZ
                                NOT NULL
                                DEFAULT now(),

    valid_to                    TIMESTAMPTZ,

    created_at                  TIMESTAMPTZ
                                NOT NULL
                                DEFAULT now(),

    updated_at                  TIMESTAMPTZ
                                NOT NULL
                                DEFAULT now(),

    CHECK (from_actor_id <> to_actor_id)
);

-- ============================================================
-- Foreign Keys
-- ============================================================

ALTER TABLE raamaesha.actor_relationships
ADD CONSTRAINT fk_actor_relationships_from_actor
FOREIGN KEY (from_actor_id)
REFERENCES raamaesha.actors(id)
ON DELETE CASCADE;

ALTER TABLE raamaesha.actor_relationships
ADD CONSTRAINT fk_actor_relationships_to_actor
FOREIGN KEY (to_actor_id)
REFERENCES raamaesha.actors(id)
ON DELETE CASCADE;
-- ============================================================
-- Indexes
-- ============================================================

CREATE INDEX idx_actor_relationships_from_actor
ON raamaesha.actor_relationships(from_actor_id);

CREATE INDEX idx_actor_relationships_to_actor
ON raamaesha.actor_relationships(to_actor_id);

CREATE INDEX idx_actor_relationships_type
ON raamaesha.actor_relationships(relationship_type);

CREATE INDEX idx_actor_relationships_active
ON raamaesha.actor_relationships(is_active);

CREATE INDEX idx_actor_relationships_valid_from

-- ============================================================
-- Unique Constraints
-- ============================================================

ALTER TABLE raamaesha.actor_relationships
ADD CONSTRAINT uq_actor_relationships
UNIQUE
(
    from_actor_id,
    to_actor_id,
    relationship_type,
    valid_from
);
-- ============================================================
-- Comments
-- ============================================================

COMMENT ON TABLE raamaesha.actor_relationships IS
'Stores relationships between all actors in the platform.';

COMMENT ON COLUMN raamaesha.actor_relationships.relationship_type IS
'Defines how two actors are connected.';
COMMIT;