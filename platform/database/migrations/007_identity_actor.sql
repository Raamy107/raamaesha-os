-- ============================================================================
-- RaamaEsha OS Founder Edition
-- Sprint 005 : Identity Platform V2
-- Migration   : 007_identity_actor.sql
-- Author      : RaamaEsha Engineering
--
-- Purpose
-- -------
-- Creates the universal Actor model.
--
-- Every identity inside the platform is represented as an Actor:
--
-- • Human
-- • AI Agent
-- • Organization
-- • Team
-- • Branch
-- • Device
-- • External System
-- • Service Account
--
-- This becomes the root identity model for the entire platform.
-- ============================================================================

BEGIN;
-- ============================================================================
-- Actor Types
-- ============================================================================

CREATE TYPE public.actor_type AS ENUM
(
    'human',
    'organization',
    'team',
    'group',
    'branch',
    'ai_agent',
    'service_account',
    'device',
    'external_system'
);
-- ============================================================
-- Actors
-- ============================================================

CREATE TABLE raamaesha.actors
(
    id                  UUID PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    actor_type          public.actor_type
                        NOT NULL,

    code                TEXT,

    display_name        TEXT
                        NOT NULL,

    legal_name          TEXT,

    description         TEXT,

    is_active           BOOLEAN
                        NOT NULL
                        DEFAULT TRUE,

    created_at          TIMESTAMPTZ
                        NOT NULL
                        DEFAULT now(),

    updated_at          TIMESTAMPTZ
                        NOT NULL
                        DEFAULT now()
);
