-- =============================================================================
-- RaamaEsha OS
-- Migration : 001_extensions.sql
-- Module    : Platform Foundation
--
-- Purpose:
--   Installs the PostgreSQL extensions required by the RaamaEsha OS platform.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Extension: pgcrypto
-- Purpose : Cryptographic functions and UUID generation
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

COMMENT ON EXTENSION pgcrypto IS
'Provides cryptographic functions including gen_random_uuid().';

-- =============================================================================
-- Extension: citext
-- Purpose : Case-insensitive text for identifiers such as email addresses.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS citext;

COMMENT ON EXTENSION citext IS
'Provides the case-insensitive CITEXT data type.';

-- =============================================================================
-- Schema: raamaesha
-- Purpose : Primary application schema
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS raamaesha;

COMMENT ON SCHEMA raamaesha IS
'Primary schema for the RaamaEsha OS platform.';

COMMIT;