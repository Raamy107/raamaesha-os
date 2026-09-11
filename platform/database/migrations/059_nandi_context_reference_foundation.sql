-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 059_nandi_context_reference_foundation.sql
-- Module    : Nandi AI Control Plane
--
-- Purpose:
--   Records contextual references associated with a Nandi invocation.
--
-- Architectural Rule:
--   Invocation records what was requested.
--   Context References record what context should be considered.
--   Context Resolver retrieves/assembles the actual runtime context.
--
-- This migration does NOT store complete context payloads.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Context Type
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_context_type'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_context_type AS ENUM (
            'identity',
            'conversation',
            'workflow',
            'business',
            'memory',
            'knowledge',
            'financial',
            'digital_asset',
            'system'
        );
    END IF;
END
$$;

-- =============================================================================
-- Context Source Type
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_context_source_type'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_context_source_type AS ENUM (
            'database',
            'conversation',
            'memory',
            'document',
            'rag',
            'workflow',
            'integration',
            'api',
            'system'
        );
    END IF;
END
$$;

-- =============================================================================
-- Tenant-Safe Parent Key
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'uq_agent_invocations_id_organization'
          AND conrelid = 'raamaesha.agent_invocations'::regclass
    ) THEN
        ALTER TABLE raamaesha.agent_invocations
            ADD CONSTRAINT uq_agent_invocations_id_organization
            UNIQUE (id, organization_id);
    END IF;
END
$$;

-- =============================================================================
-- Updated At Helper
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_agent_invocation_context_refs_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- Context Reference Mutability
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_agent_invocation_context_refs_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_status raamaesha.agent_invocation_status;
    v_invocation_id UUID;
    v_organization_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_invocation_id := OLD.agent_invocation_id;
        v_organization_id := OLD.organization_id;
    ELSE
        v_invocation_id := NEW.agent_invocation_id;
        v_organization_id := NEW.organization_id;
    END IF;

    SELECT ai.status
      INTO v_status
      FROM raamaesha.agent_invocations ai
     WHERE ai.id = v_invocation_id
       AND ai.organization_id = v_organization_id
       AND ai.deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Cannot modify context reference: invocation % was not found for organization %',
            v_invocation_id,
            v_organization_id;
    END IF;

    IF v_status IN (
        'completed',
        'failed',
        'cancelled'
    ) THEN
        RAISE EXCEPTION
            'Cannot modify context reference for terminal invocation % with status %',
            v_invocation_id,
            v_status;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- Agent Invocation Context References
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.agent_invocation_context_refs (
    id UUID NOT NULL DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_invocation_id UUID NOT NULL,

    context_type raamaesha.agent_invocation_context_type NOT NULL,

    source_type raamaesha.agent_invocation_context_source_type NOT NULL,

    source_id UUID NULL,

    reference_key TEXT NULL,

    priority INTEGER NOT NULL DEFAULT 100,

    is_required BOOLEAN NOT NULL DEFAULT FALSE,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_by UUID NULL,

    updated_by UUID NULL,

    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT pk_agent_invocation_context_refs
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_invocation_context_refs_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_context_refs_invocation
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_context_refs_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_context_refs_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_agent_invocation_context_refs_reference
        CHECK (
            source_id IS NOT NULL
            OR reference_key IS NOT NULL
        ),

    CONSTRAINT ck_agent_invocation_context_refs_reference_key
        CHECK (
            reference_key IS NULL
            OR length(btrim(reference_key)) > 0
        ),

    CONSTRAINT ck_agent_invocation_context_refs_priority
        CHECK (
            priority >= 0
        ),

    CONSTRAINT ck_agent_invocation_context_refs_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )
);

-- =============================================================================
-- Active Reference Uniqueness
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_invocation_context_refs_active_reference
    ON raamaesha.agent_invocation_context_refs (
        agent_invocation_id,
        context_type,
        source_type,
        source_id,
        reference_key
    ) NULLS NOT DISTINCT
    WHERE deleted_at IS NULL;

-- =============================================================================
-- Lookup Indexes
-- =============================================================================

CREATE INDEX IF NOT EXISTS ix_agent_invocation_context_refs_invocation
    ON raamaesha.agent_invocation_context_refs (
        agent_invocation_id
    )
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_context_refs_organization_context
    ON raamaesha.agent_invocation_context_refs (
        organization_id,
        context_type
    )
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_context_refs_source
    ON raamaesha.agent_invocation_context_refs (
        source_type,
        source_id
    )
    WHERE deleted_at IS NULL
      AND source_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_context_refs_invocation_priority
    ON raamaesha.agent_invocation_context_refs (
        agent_invocation_id,
        priority
    )
    WHERE deleted_at IS NULL;

-- =============================================================================
-- Updated At Trigger
-- =============================================================================

DROP TRIGGER IF EXISTS trg_agent_invocation_context_refs_updated_at
    ON raamaesha.agent_invocation_context_refs;

CREATE TRIGGER trg_agent_invocation_context_refs_updated_at
BEFORE UPDATE ON raamaesha.agent_invocation_context_refs
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_agent_invocation_context_refs_updated_at();

-- =============================================================================
-- Terminal Invocation Immutability Trigger
-- =============================================================================

DROP TRIGGER IF EXISTS trg_agent_invocation_context_refs_immutability
    ON raamaesha.agent_invocation_context_refs;

CREATE TRIGGER trg_agent_invocation_context_refs_immutability
BEFORE INSERT OR UPDATE OR DELETE
ON raamaesha.agent_invocation_context_refs
FOR EACH ROW
EXECUTE FUNCTION raamaesha.enforce_agent_invocation_context_refs_mutability();

COMMIT;
