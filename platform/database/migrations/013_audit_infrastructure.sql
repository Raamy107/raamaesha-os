-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 013_audit_infrastructure.sql
-- Module    : Platform Foundation
--
-- Purpose:
--   Creates reusable audit infrastructure for automatically maintaining
--   updated_at timestamps across the platform.
--
-- Responsibilities:
--   - Reusable trigger function
--   - Audit triggers
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Audit Trigger Function
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION raamaesha.set_updated_at()
IS 'Automatically updates the updated_at column before each row update.';

-- =============================================================================
-- Organizations
-- =============================================================================

CREATE TRIGGER trg_organizations_set_updated_at
BEFORE UPDATE
ON raamaesha.organizations
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Countries
-- =============================================================================

CREATE TRIGGER trg_countries_set_updated_at
BEFORE UPDATE
ON raamaesha.countries
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Actors
-- =============================================================================

CREATE TRIGGER trg_actors_set_updated_at
BEFORE UPDATE
ON raamaesha.actors
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Actor Relationships
-- =============================================================================

CREATE TRIGGER trg_actor_relationships_set_updated_at
BEFORE UPDATE
ON raamaesha.actor_relationships
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Roles
-- =============================================================================

CREATE TRIGGER trg_roles_set_updated_at
BEFORE UPDATE
ON raamaesha.roles
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Permissions
-- =============================================================================

CREATE TRIGGER trg_permissions_set_updated_at
BEFORE UPDATE
ON raamaesha.permissions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Role Permissions
-- =============================================================================

CREATE TRIGGER trg_role_permissions_set_updated_at
BEFORE UPDATE
ON raamaesha.role_permissions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Actor Roles
-- =============================================================================

CREATE TRIGGER trg_actor_roles_set_updated_at
BEFORE UPDATE
ON raamaesha.actor_roles
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;