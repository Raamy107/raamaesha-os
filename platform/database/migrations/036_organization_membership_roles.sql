-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 036_organization_membership_roles.sql
-- Module    : Identity & Organization Authorization
--
-- Purpose:
--   Creates the organization-scoped role assignment model for organization
--   memberships.
--
-- Responsibilities:
--   - Membership-to-role assignments
--   - Organization role scope enforcement
--   - Temporal role assignments
--   - Role assignment lifecycle
--   - Role assignment audit metadata
--   - Soft deletion
--   - Database-enforced role assignment integrity
--
-- Design Principles:
--   - Actors remain the universal identity model
--   - Organizations remain tenant boundaries
--   - Membership establishes tenant participation
--   - Roles remain reusable authorization definitions
--   - Organization roles are assigned through memberships
--   - Generic actor_roles remains available for non-membership assignments
--   - Organization role scope is database enforced
--   - Historical assignments remain preserved
--   - One current membership-role assignment exists per pair
--   - No authentication logic
--   - No permission definition logic
--   - No runtime execution logic
--
-- Dependencies:
--   - 009_identity_roles.sql
--   - 035_organization_memberships.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Role Reference Integrity
-- =============================================================================
--
-- The existing roles table has a unique business key of (code, scope), but
-- organization membership role assignments need to enforce the role scope
-- directly through a composite foreign key.
--
-- PostgreSQL requires the referenced columns to be covered by a UNIQUE or
-- PRIMARY KEY constraint.
-- =============================================================================

-- Composite role key (id, scope) is already established for role-scope integrity.


-- =============================================================================
-- Table : organization_membership_roles
-- =============================================================================
--
-- Represents an organization-scoped role assigned to an organization
-- membership.
--
-- The membership establishes the tenant boundary while the role establishes
-- the authorization definition.
-- =============================================================================

CREATE TABLE raamaesha.organization_membership_roles
(
    id                          UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    membership_id               UUID
        NOT NULL,

    role_id                     UUID
        NOT NULL,

    role_scope                  public.role_scope
        NOT NULL
        DEFAULT 'organization',

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


    -- =========================================================================
    -- Primary Key
    -- =========================================================================

    CONSTRAINT pk_organization_membership_roles
        PRIMARY KEY (id),


    -- =========================================================================
    -- Membership Relationship
    -- =========================================================================

    CONSTRAINT fk_organization_membership_roles_membership
        FOREIGN KEY (membership_id)
        REFERENCES raamaesha.organization_memberships(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Organization Role Scope
    -- =========================================================================
    --
    -- role_scope is intentionally fixed to organization scope.
    -- The composite foreign key below additionally guarantees that the
    -- referenced role itself has organization scope.
    -- =========================================================================

    CONSTRAINT ck_organization_membership_roles_scope
        CHECK (
            role_scope = 'organization'
        ),

    CONSTRAINT fk_organization_membership_roles_role_scope
        FOREIGN KEY (role_id, role_scope)
        REFERENCES raamaesha.roles(id, scope)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Temporal Validity
    -- =========================================================================

    CONSTRAINT ck_organization_membership_roles_valid_period
        CHECK (
            valid_to IS NULL
            OR valid_to >= valid_from
        ),


    -- =========================================================================
    -- Audit Actor Relationships
    -- =========================================================================

    CONSTRAINT fk_organization_membership_roles_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_organization_membership_roles_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
);


-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.organization_membership_roles IS
'Assigns organization-scoped roles to organization memberships within the RaamaEsha OS tenant authorization model.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.id IS
'Globally unique identifier for the organization membership role assignment.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.membership_id IS
'Organization membership receiving the role assignment.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.role_id IS
'Organization-scoped role assigned to the membership.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.role_scope IS
'Authorization scope of the assigned role. This value is fixed to organization scope.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.valid_from IS
'Timestamp when the role assignment becomes effective.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.valid_to IS
'Timestamp when the role assignment expires. NULL indicates no scheduled expiration.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.is_active IS
'Indicates whether the role assignment is currently active.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.created_at IS
'Timestamp when the role assignment record was created.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.updated_at IS
'Timestamp when the role assignment record was last updated.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.created_by IS
'Actor that created the role assignment.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.updated_by IS
'Actor that last modified the role assignment.';


COMMENT ON COLUMN raamaesha.organization_membership_roles.deleted_at IS
'Soft deletion timestamp. NULL indicates that the role assignment has not been soft deleted.';


-- =============================================================================
-- Referential Indexes
-- =============================================================================

CREATE INDEX idx_organization_membership_roles_membership
    ON raamaesha.organization_membership_roles (membership_id);


CREATE INDEX idx_organization_membership_roles_role
    ON raamaesha.organization_membership_roles (role_id);


CREATE INDEX idx_organization_membership_roles_active
    ON raamaesha.organization_membership_roles (is_active);


CREATE INDEX idx_organization_membership_roles_valid_from
    ON raamaesha.organization_membership_roles (valid_from);


CREATE INDEX idx_organization_membership_roles_valid_to
    ON raamaesha.organization_membership_roles (valid_to);


CREATE INDEX idx_organization_membership_roles_deleted_at
    ON raamaesha.organization_membership_roles (deleted_at);


-- =============================================================================
-- Current Assignment Uniqueness
-- =============================================================================
--
-- A membership may hold multiple different roles, but the same role must not
-- be assigned more than once in the current non-deleted state.
--
-- Historical assignments remain possible after soft deletion.
-- =============================================================================

CREATE UNIQUE INDEX ux_organization_membership_roles_one_current
    ON raamaesha.organization_membership_roles
    (
        membership_id,
        role_id
    )
    WHERE deleted_at IS NULL;


-- =============================================================================
-- Index Documentation
-- =============================================================================

COMMENT ON INDEX
    raamaesha.ux_organization_membership_roles_one_current IS
'Ensures that a membership has at most one current non-deleted assignment of a specific organization role.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 036
-- =============================================================================

