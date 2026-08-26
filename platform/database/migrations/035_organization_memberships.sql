-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 035_organization_memberships.sql
-- Module    : Identity & Organization Membership
--
-- Purpose:
--   Creates the explicit organization membership model for actors.
--
-- Responsibilities:
--   - Organization membership identity
--   - Actor-to-organization membership
--   - Membership lifecycle
--   - Membership validity period
--   - Membership audit metadata
--   - Soft deletion
--   - Database-enforced membership integrity
--
-- Design Principles:
--   - Actors remain the universal identity model
--   - Organizations remain tenant boundaries
--   - Membership is explicitly modeled rather than inferred
--     from generic actor relationships
--   - One current membership exists per organization/actor pair
--   - Historical membership records remain preserved
--   - Database-enforced lifecycle integrity
--   - No role assignment logic
--   - No permission logic
--   - No authentication logic
--   - No runtime execution logic
--
-- Dependencies:
--   - 003_schema_core.sql
--   - 007_identity_actor.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- ENUM : organization_membership_status
-- =============================================================================
--
-- Defines the lifecycle state of an actor's membership within an
-- organization.
-- =============================================================================

CREATE TYPE public.organization_membership_status AS ENUM
(
    'pending',
    'active',
    'suspended',
    'inactive'
);


COMMENT ON TYPE public.organization_membership_status IS
'Defines the lifecycle states of an actor membership within an organization.';


-- =============================================================================
-- Table : organization_memberships
-- =============================================================================
--
-- Explicitly represents the relationship between an actor and an
-- organization.
--
-- This table establishes the tenant membership boundary for actors.
-- =============================================================================

CREATE TABLE raamaesha.organization_memberships
(
    id                          UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id             UUID
        NOT NULL,

    actor_id                    UUID
        NOT NULL,

    status                      public.organization_membership_status
        NOT NULL
        DEFAULT 'pending',

    joined_at                   TIMESTAMPTZ,

    left_at                     TIMESTAMPTZ,

    created_at                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at                  TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by                  UUID,

    updated_by                  UUID,

    deleted_at                  TIMESTAMPTZ,


    -- =========================================================================
    -- Primary Key
    -- =========================================================================

    CONSTRAINT pk_organization_memberships
        PRIMARY KEY (id),


    -- =========================================================================
    -- Organization Relationship
    -- =========================================================================

    CONSTRAINT fk_organization_memberships_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Actor Relationship
    -- =========================================================================

    CONSTRAINT fk_organization_memberships_actor
        FOREIGN KEY (actor_id)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Audit Actor Relationships
    -- =========================================================================

    CONSTRAINT fk_organization_memberships_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_organization_memberships_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- Membership Date Integrity
    -- =========================================================================

    CONSTRAINT ck_organization_memberships_joined_before_left
        CHECK (
            left_at IS NULL
            OR joined_at IS NULL
            OR left_at >= joined_at
        )
);


-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.organization_memberships IS
'Explicit membership records connecting actors to tenant organizations within the RaamaEsha OS platform.';


COMMENT ON COLUMN raamaesha.organization_memberships.id IS
'Globally unique identifier for the organization membership record.';


COMMENT ON COLUMN raamaesha.organization_memberships.organization_id IS
'Organization in which the actor holds or held membership.';


COMMENT ON COLUMN raamaesha.organization_memberships.actor_id IS
'Actor holding or having held membership in the organization.';


COMMENT ON COLUMN raamaesha.organization_memberships.status IS
'Current lifecycle state of the organization membership.';


COMMENT ON COLUMN raamaesha.organization_memberships.joined_at IS
'Timestamp at which the actor joined the organization.';


COMMENT ON COLUMN raamaesha.organization_memberships.left_at IS
'Timestamp at which the actor left the organization. NULL indicates no recorded departure.';


COMMENT ON COLUMN raamaesha.organization_memberships.created_at IS
'Timestamp when the membership record was created.';


COMMENT ON COLUMN raamaesha.organization_memberships.updated_at IS
'Timestamp when the membership record was last updated.';


COMMENT ON COLUMN raamaesha.organization_memberships.created_by IS
'Actor that created the membership record.';


COMMENT ON COLUMN raamaesha.organization_memberships.updated_by IS
'Actor that last updated the membership record.';


COMMENT ON COLUMN raamaesha.organization_memberships.deleted_at IS
'Soft deletion timestamp. NULL indicates that the membership record has not been soft deleted.';


-- =============================================================================
-- Referential Indexes
-- =============================================================================

CREATE INDEX idx_organization_memberships_organization_id
    ON raamaesha.organization_memberships (organization_id);


CREATE INDEX idx_organization_memberships_actor_id
    ON raamaesha.organization_memberships (actor_id);


CREATE INDEX idx_organization_memberships_status
    ON raamaesha.organization_memberships (status);


CREATE INDEX idx_organization_memberships_joined_at
    ON raamaesha.organization_memberships (joined_at);


CREATE INDEX idx_organization_memberships_left_at
    ON raamaesha.organization_memberships (left_at);


CREATE INDEX idx_organization_memberships_deleted_at
    ON raamaesha.organization_memberships (deleted_at);


-- =============================================================================
-- Current Membership Uniqueness
-- =============================================================================
--
-- A historical membership record may exist for the same actor and
-- organization after soft deletion.
--
-- Only one non-deleted membership record may represent the current
-- organization/actor relationship.
--
-- Both indexed columns are NOT NULL, therefore NULLS NOT DISTINCT
-- is not required.
-- =============================================================================

CREATE UNIQUE INDEX ux_organization_memberships_one_current
    ON raamaesha.organization_memberships
    (
        organization_id,
        actor_id
    )
    WHERE deleted_at IS NULL;


-- =============================================================================
-- Active Membership Integrity
-- =============================================================================
--
-- An active membership must represent an actor who has actually joined
-- the organization.
-- =============================================================================

ALTER TABLE raamaesha.organization_memberships
    ADD CONSTRAINT ck_organization_memberships_active_has_joined_at
        CHECK (
            status <> 'active'
            OR joined_at IS NOT NULL
        );


-- =============================================================================
-- Membership Lifecycle Integrity
-- =============================================================================
--
-- A departure timestamp cannot precede the membership start timestamp.
--
-- The joined_before_left constraint above protects this invariant.
--
-- No additional runtime state-transition logic is introduced in this
-- migration.
-- =============================================================================


-- =============================================================================
-- Constraint Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_organization_memberships_joined_before_left
ON raamaesha.organization_memberships IS
'Ensures that a membership departure timestamp cannot occur before the membership start timestamp.';


COMMENT ON CONSTRAINT
    ck_organization_memberships_active_has_joined_at
ON raamaesha.organization_memberships IS
'Ensures that an active organization membership has a recorded membership start timestamp.';


-- =============================================================================
-- Index Documentation
-- =============================================================================

COMMENT ON INDEX
    raamaesha.ux_organization_memberships_one_current IS
'Ensures that an actor has at most one non-deleted membership record within an organization.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 035
-- =============================================================================

