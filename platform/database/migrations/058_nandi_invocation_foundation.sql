-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 058_nandi_invocation_foundation.sql
-- Module    : Nandi Control Plane / Invocation Foundation
--
-- Purpose:
--   Records requests entering the Nandi AI Control Plane.
--
-- Architectural Rule:
--   Invocation records the request.
--   Nandi makes decisions.
--   Governance controls permission.
--   Agent Runtime executes.
--   Run Steps record execution stages.
--   Integration Execution records actual external operations.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Invocation Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_status'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_status AS ENUM (
            'received',
            'resolving',
            'contextualizing',
            'planning',
            'executing',
            'completed',
            'failed',
            'cancelled',
            'waiting_for_approval'
        );
    END IF;
END
$$;

-- =============================================================================
-- Invocation Source
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_source'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_source AS ENUM (
            'user',
            'workflow',
            'event',
            'api',
            'schedule',
            'system'
        );
    END IF;
END
$$;

-- =============================================================================
-- Agent Invocations
-- =============================================================================

CREATE TABLE raamaesha.agent_invocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    source_type raamaesha.agent_invocation_source NOT NULL,

    actor_id UUID NULL,


    agent_run_id UUID NULL,

    request_type TEXT NOT NULL,
    request_payload JSONB NOT NULL DEFAULT '{}'::jsonb,

    correlation_id UUID NOT NULL,

    status raamaesha.agent_invocation_status NOT NULL
        DEFAULT 'received',
    result_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    error_code TEXT NULL,

    error_message TEXT NULL,

    error_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    started_at TIMESTAMPTZ NULL,

    completed_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    created_by UUID NULL,

    updated_by UUID NULL,

    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT fk_agent_invocations_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocations_actor
        FOREIGN KEY (actor_id)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocations_agent_run
        FOREIGN KEY (agent_run_id, organization_id)
        REFERENCES raamaesha.agent_runs(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocations_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocations_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_agent_invocations_request_payload_object
        CHECK (jsonb_typeof(request_payload) = 'object'),

    CONSTRAINT chk_agent_invocations_result_metadata_object
        CHECK (jsonb_typeof(result_metadata) = 'object'),

    CONSTRAINT chk_agent_invocations_error_metadata_object
        CHECK (jsonb_typeof(error_metadata) = 'object'),

    CONSTRAINT chk_agent_invocations_lifecycle_timestamps
        CHECK (
            (
                status = 'received'
                AND started_at IS NULL
                AND completed_at IS NULL
            )
            OR
            (
                status IN ('resolving', 'contextualizing', 'planning', 'executing', 'waiting_for_approval')
                AND started_at IS NOT NULL
                AND completed_at IS NULL
            )
            OR
            (
                status IN ('completed', 'failed', 'cancelled')
                AND started_at IS NOT NULL
                AND completed_at IS NOT NULL
            )
        ),

    CONSTRAINT chk_agent_invocations_completion_after_start
        CHECK (
            completed_at IS NULL
            OR started_at IS NULL
            OR completed_at >= started_at
        ),

    CONSTRAINT chk_agent_invocations_error_code
        CHECK (
            status <> 'failed'
            OR error_code IS NOT NULL
        )
);

-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX ix_agent_invocations_organization
    ON raamaesha.agent_invocations (organization_id);

CREATE INDEX ix_agent_invocations_correlation
    ON raamaesha.agent_invocations (correlation_id);

CREATE INDEX ix_agent_invocations_status
    ON raamaesha.agent_invocations (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocations_agent_run
    ON raamaesha.agent_invocations (agent_run_id)
    WHERE agent_run_id IS NOT NULL;

CREATE INDEX ix_agent_invocations_actor
    ON raamaesha.agent_invocations (actor_id)
    WHERE actor_id IS NOT NULL;

-- =============================================================================
-- Updated At
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_agent_invocations_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_agent_invocations_updated_at
BEFORE UPDATE ON raamaesha.agent_invocations
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_agent_invocations_updated_at();

COMMIT;

-- =============================================================================
-- End Migration 058
-- =============================================================================









