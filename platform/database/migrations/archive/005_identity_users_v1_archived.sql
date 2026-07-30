-- ============================================================================
-- RaamaEsha OS Founder Edition v1.0
-- Migration: 005_identity_users.sql
-- Purpose : Identity Management - Users
-- Author  : RaamaEsha Engineering
-- ============================================================================
-- Description
-- ----------------------------------------------------------------------------
-- Creates the master users table used across the RaamaEsha OS platform.
-- This table stores user identity independent of authentication providers.
-- Authentication credentials are maintained separately.
-- ============================================================================

BEGIN;

-- ============================================================================
-- Table : users
-- Purpose : Master identity records for all platform users.
-- ============================================================================

CREATE TABLE raamaesha.users
(    
    id                  UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    display_name        TEXT
        NOT NULL,

    first_name          TEXT,

    last_name           TEXT,

    full_name           TEXT
        GENERATED ALWAYS AS
        (
            trim(
                concat_ws(
                    ' ',
                    first_name,
                    last_name
                )
            )
        ) STORED,

    profile_photo_url   TEXT,

    date_of_birth       DATE,

    gender              public.gender,

    preferred_language  TEXT,

    timezone            TEXT
        DEFAULT 'UTC',
    
