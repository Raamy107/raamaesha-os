-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 040_role_scope_reference_integrity.sql
-- Module    : Identity & Organization Authorization Integrity
--
-- Purpose:
--   Establish the composite role reference key required by organization-scoped
--   role assignments.
--
-- Responsibilities:
--   - Provide composite uniqueness for (role id, role scope)
--   - Support composite foreign-key references from organization membership roles
--   - Preserve existing role business uniqueness semantics
--   - Reconcile the existing database index through forward-only migration
--
-- Design Principles:
--   - Role identity remains PRIMARY KEY (id)
--   - Role business uniqueness remains UNIQUE (code, scope)
--   - Composite (id, scope) uniqueness exists specifically to support
--     scope-aware foreign-key references
--   - No new authorization semantics are introduced
--   - No authentication logic
--   - No permission definition logic
--   - No runtime execution logic
--   - No historical migration modification
--
-- Dependencies:
--   - 009_identity_roles.sql
--   - 036_organization_membership_roles.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Composite Role Reference Key
-- =============================================================================
--
-- PostgreSQL requires the referenced columns of a composite foreign key
-- to be covered by a PRIMARY KEY or UNIQUE constraint.
--
-- Migration 036 references:
--
--     raamaesha.roles (id, scope)
--
-- The roles table already has:
--
--     PRIMARY KEY (id)
--     UNIQUE (code, scope)
--
-- The composite key below exists specifically to support the scope-aware
-- foreign-key relationship used by organization membership role assignments.
--
-- This does NOT replace the business uniqueness rule (code, scope).
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_roles_id_scope
    ON raamaesha.roles
    (
        id,
        scope
    );


-- =============================================================================
-- Index Documentation
-- =============================================================================

COMMENT ON INDEX
    raamaesha.uq_roles_id_scope IS
'Provides the composite (id, scope) reference key required by scope-aware role foreign keys. This index supports referential integrity and does not replace the role business uniqueness rule (code, scope).';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 040
-- =============================================================================