-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 060_nandi_context_resolution_foundation.sql
-- Module    : Nandi AI Control Plane
--
-- Purpose:
--   Records resolution attempts and outcomes for Nandi context references.
--
-- Architectural Rule:
--   058 Invocation records what was requested.
--   059 Context References record what context should be considered.
--   060 Context Resolution records how those references were resolved.
--   The actual runtime context package is assembled by the Context Resolver.
--
-- This migration does NOT store complete context payloads.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Context Resolution Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_context_resolution_status'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_context_resolution_status AS ENUM (
            'pending',
            'resolving',
            'resolved',
            'failed',
            'skipped'
        );
    END IF;
END
$$;

-- =============================================================================
-- Tenant-safe unique key for Context References
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_agent_invocation_context_refs_id_organization'
          AND conrelid = 'raamaesha.agent_invocation_context_refs'::regclass
    ) THEN
        ALTER TABLE raamaesha.agent_invocation_context_refs
            ADD CONSTRAINT uq_agent_invocation_context_refs_id_organization
            UNIQUE (id, organization_id);
    END IF;
END
$$;

-- =============================================================================
-- Updated-at Function
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.set_agent_invocation_context_resolutions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- Resolution Mutability
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_agent_invocation_context_resolutions_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN

        IF OLD.status IN (
            'resolved',
            'failed',
            'skipped'
        ) THEN
            RAISE EXCEPTION
                'Cannot delete terminal context resolution % with status %',
                OLD.id,
                OLD.status;
        END IF;

        RETURN OLD;
    END IF;

    IF TG_OP = 'UPDATE' THEN

        IF OLD.status IN (
            'resolved',
            'failed',
            'skipped'
        ) THEN
            RAISE EXCEPTION
                'Cannot modify terminal context resolution % with status %',
                OLD.id,
                OLD.status;
        END IF;

        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- Agent Invocation Context Resolutions
-- =============================================================================

CREATE TABLE IF NOT EXISTS
    raamaesha.agent_invocation_context_resolutions (

    id UUID NOT NULL DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    context_ref_id UUID NOT NULL,

    attempt_no INTEGER NOT NULL DEFAULT 1,

    status
        raamaesha.agent_invocation_context_resolution_status
        NOT NULL DEFAULT 'pending',

    resolver_type TEXT NOT NULL,

    resolved_at TIMESTAMPTZ NULL,

    error_code TEXT NULL,

    error_message TEXT NULL,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_by UUID NULL,

    updated_by UUID NULL,

    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT pk_agent_invocation_context_resolutions
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_invocation_context_resolutions_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_context_resolutions_context_ref
        FOREIGN KEY (context_ref_id, organization_id)
        REFERENCES raamaesha.agent_invocation_context_refs(
            id,
            organization_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_context_resolutions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_context_resolutions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_agent_invocation_context_resolutions_attempt_no
        CHECK (
            attempt_no >= 1
        ),

    CONSTRAINT ck_agent_invocation_context_resolutions_resolver_type
        CHECK (
            length(btrim(resolver_type)) > 0
        ),

    CONSTRAINT ck_agent_invocation_context_resolutions_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        ),

    CONSTRAINT ck_agent_invocation_context_resolutions_lifecycle
        CHECK (
            (
                status IN ('pending', 'resolving')
                AND resolved_at IS NULL
            )
            OR
            (
                status IN ('resolved', 'failed', 'skipped')
                AND resolved_at IS NOT NULL
            )
        ),

    CONSTRAINT ck_agent_invocation_context_resolutions_error_consistency
        CHECK (
            status <> 'failed'
            OR error_code IS NOT NULL
        ),

    CONSTRAINT ck_agent_invocation_context_resolutions_error_code
        CHECK (
            error_code IS NULL
            OR length(btrim(error_code)) > 0
        ),

    CONSTRAINT ck_agent_invocation_context_resolutions_error_message
        CHECK (
            error_message IS NULL
            OR length(btrim(error_message)) > 0
        )
);

-- =============================================================================
-- Resolution Attempt Uniqueness
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS
    uq_agent_invocation_context_resolutions_active_attempt
ON raamaesha.agent_invocation_context_resolutions (
    context_ref_id,
    attempt_no
)
WHERE deleted_at IS NULL;

-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX IF NOT EXISTS
    ix_agent_invocation_context_resolutions_context_ref
ON raamaesha.agent_invocation_context_resolutions (
    context_ref_id
)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS
    ix_agent_invocation_context_resolutions_organization_status
ON raamaesha.agent_invocation_context_resolutions (
    organization_id,
    status
)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS
    ix_agent_invocation_context_resolutions_resolver_type
ON raamaesha.agent_invocation_context_resolutions (
    resolver_type
)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS
    ix_agent_invocation_context_resolutions_context_attempt
ON raamaesha.agent_invocation_context_resolutions (
    context_ref_id,
    attempt_no
)
WHERE deleted_at IS NULL;

-- =============================================================================
-- Updated-at Trigger
-- =============================================================================

DROP TRIGGER IF EXISTS
    trg_agent_invocation_context_resolutions_updated_at
ON raamaesha.agent_invocation_context_resolutions;

CREATE TRIGGER
    trg_agent_invocation_context_resolutions_updated_at
BEFORE UPDATE
ON raamaesha.agent_invocation_context_resolutions
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.set_agent_invocation_context_resolutions_updated_at();

-- =============================================================================
-- Terminal Immutability Trigger
-- =============================================================================

DROP TRIGGER IF EXISTS
    trg_agent_invocation_context_resolutions_immutability
ON raamaesha.agent_invocation_context_resolutions;

CREATE TRIGGER
    trg_agent_invocation_context_resolutions_immutability
BEFORE INSERT OR UPDATE OR DELETE
ON raamaesha.agent_invocation_context_resolutions
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_agent_invocation_context_resolutions_mutability();

COMMIT;