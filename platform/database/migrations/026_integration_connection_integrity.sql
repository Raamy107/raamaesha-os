-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 026_integration_connection_integrity.sql
-- Module    : Integration Connection Integrity
--
-- Purpose:
--   Hardens the lifecycle integrity of integration connections created
--   by Migration 018.
--
-- Responsibilities:
--   - Enforce one active primary connection per integration
--   - Preserve soft-deleted connection history
--   - Allow multiple non-primary connections
--   - Correct historical schema through a forward-only migration
--
-- Dependencies:
--   - 018_integration_platform.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- One Active Primary Connection Per Integration
-- =============================================================================
--
-- A normal index cannot prevent multiple primary connections.
--
-- This unique partial index enforces the business invariant:
--
--   One active, non-deleted primary connection per integration.
--
-- Multiple non-primary connections remain valid.
-- Inactive or soft-deleted historical connections do not block a new primary.
-- =============================================================================

DROP INDEX IF EXISTS raamaesha.ux_integration_connections_one_primary;


CREATE UNIQUE INDEX ux_integration_connections_one_primary
    ON raamaesha.integration_connections (integration_id)
    WHERE is_primary = TRUE
      AND is_active = TRUE
      AND deleted_at IS NULL;


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON INDEX
    raamaesha.ux_integration_connections_one_primary IS
'Ensures that each integration has at most one active, non-deleted primary connection.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;