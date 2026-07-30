-- =============================================================================
-- RaamaEsha OS
-- Migration : 002_types.sql
-- Module    : Platform Foundation
--
-- Purpose:
--   Defines PostgreSQL shared types that are reused across multiple
--   platform modules.
--
-- Notes:
--   As of EPB v1.0, no platform-wide shared types are required.
--   Module-specific ENUMs are defined within their respective migrations.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- This migration is intentionally empty.
-- Shared platform ENUMs will be introduced here only when they are reused
-- across multiple modules.
-- =============================================================================

COMMIT;