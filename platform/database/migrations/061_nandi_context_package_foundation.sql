-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 061_nandi_context_package_foundation.sql
-- Module    : Nandi Context Platform
--
-- Purpose:
--   Creates the runtime context package foundation for the Nandi AI Control
--   Plane.
--
-- Responsibilities:
--   - Persist runtime context package identity
--   - Maintain tenant ownership
--   - Link packages to Nandi invocations
--   - Track package version and lifecycle
--   - Preserve package integrity through a context hash
--   - Record resolution/error metadata
--   - Protect terminal historical packages from mutation
--
-- Architecture:
--   058 Invocation
--        Ã¢â€ â€œ
--   059 Context References
--        Ã¢â€ â€œ
--   060 Context Resolutions
--        Ã¢â€ â€œ
--   061 Context Package
--        Ã¢â€ â€œ
--   Nandi Planning
--
-- Important:
--   This migration does NOT persist full conversations, documents, RAG chunks,
--   secrets, prompts, or hidden chain-of-thought.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. ENUM
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_context_package_status'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_context_package_status AS ENUM (
            'building',
            'ready',
            'consumed',
            'superseded',
            'failed'
        );
    END IF;
END
$$;

-- =============================================================================
-- 2. TENANT-SAFE PARENT KEY
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid =
            'raamaesha.agent_invocations'::regclass
          AND conname =
            'uq_agent_invocations_id_organization'
    ) THEN
        ALTER TABLE raamaesha.agent_invocations
            ADD CONSTRAINT uq_agent_invocations_id_organization
            UNIQUE (id, organization_id);
    END IF;
END
$$;

-- =============================================================================
-- 3. TABLE
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.agent_invocation_context_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_invocation_id UUID NOT NULL,

    package_version INTEGER NOT NULL DEFAULT 1,

    status raamaesha.agent_invocation_context_package_status
        NOT NULL DEFAULT 'building',

    resolution_count INTEGER NOT NULL DEFAULT 0,

    context_hash TEXT NOT NULL,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    error_code TEXT,

    error_message TEXT,

    error_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_by UUID,

    updated_by UUID,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT fk_agent_invocation_context_packages_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_context_packages_invocation
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_context_packages_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_context_packages_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_agent_invocation_context_packages_package_version
        CHECK (package_version >= 1),

    CONSTRAINT ck_agent_invocation_context_packages_resolution_count
        CHECK (resolution_count >= 0),

    CONSTRAINT ck_agent_invocation_context_packages_context_hash
        CHECK (length(btrim(context_hash)) > 0),

    CONSTRAINT ck_agent_invocation_context_packages_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object'),

    CONSTRAINT ck_agent_invocation_context_packages_error_code
        CHECK (
            error_code IS NULL
            OR length(btrim(error_code)) > 0
        ),

    CONSTRAINT ck_agent_invocation_context_packages_error_message
        CHECK (
            error_message IS NULL
            OR length(btrim(error_message)) > 0
        ),

    CONSTRAINT ck_agent_invocation_context_packages_error_metadata_object
        CHECK (jsonb_typeof(error_metadata) = 'object'),

    CONSTRAINT ck_agent_invocation_context_packages_error_consistency
        CHECK (
            status <> 'failed'::raamaesha.agent_invocation_context_package_status
            OR error_code IS NOT NULL
        )
);

-- =============================================================================
-- 4. INDEXES
-- =============================================================================

CREATE INDEX IF NOT EXISTS
    ix_agent_invocation_context_packages_invocation
ON raamaesha.agent_invocation_context_packages
    (agent_invocation_id)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS
    ix_agent_invocation_context_packages_organization_status
ON raamaesha.agent_invocation_context_packages
    (organization_id, status)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS
    ix_agent_invocation_context_packages_invocation_version
ON raamaesha.agent_invocation_context_packages
    (agent_invocation_id, package_version)
WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS
    uq_agent_invocation_context_packages_active_version
ON raamaesha.agent_invocation_context_packages
    (agent_invocation_id, package_version)
WHERE deleted_at IS NULL;

-- =============================================================================
-- 5. UPDATED_AT FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.set_agent_invocation_context_packages_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- 6. IMMUTABILITY FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_agent_invocation_context_packages_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        RETURN NEW;
    END IF;

    IF OLD.status IN (
        'consumed'::raamaesha.agent_invocation_context_package_status,
        'superseded'::raamaesha.agent_invocation_context_package_status,
        'failed'::raamaesha.agent_invocation_context_package_status
    ) THEN
        RAISE EXCEPTION
            'Context package % is immutable because its status is %',
            OLD.id,
            OLD.status;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- 7. TRIGGERS
-- =============================================================================

DROP TRIGGER IF EXISTS
    trg_agent_invocation_context_packages_updated_at
ON raamaesha.agent_invocation_context_packages;

CREATE TRIGGER
    trg_agent_invocation_context_packages_updated_at
BEFORE UPDATE
ON raamaesha.agent_invocation_context_packages
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.set_agent_invocation_context_packages_updated_at();

DROP TRIGGER IF EXISTS
    trg_agent_invocation_context_packages_immutability
ON raamaesha.agent_invocation_context_packages;

CREATE TRIGGER
    trg_agent_invocation_context_packages_immutability
BEFORE INSERT OR UPDATE OR DELETE
ON raamaesha.agent_invocation_context_packages
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_agent_invocation_context_packages_mutability();

-- =============================================================================
-- 8. COMMENTS
-- =============================================================================

COMMENT ON TABLE
    raamaesha.agent_invocation_context_packages
IS
    'Runtime context package identity and lifecycle for the Nandi AI Control Plane.';

COMMENT ON COLUMN
    raamaesha.agent_invocation_context_packages.context_hash
IS
    'Integrity fingerprint of the assembled runtime context; actual context payload is not stored here.';

COMMENT ON COLUMN
    raamaesha.agent_invocation_context_packages.metadata
IS
    'Non-sensitive package metadata. Must remain a JSON object.';

COMMENT ON COLUMN
    raamaesha.agent_invocation_context_packages.error_metadata
IS
    'Structured non-sensitive metadata describing package assembly failure.';

-- =============================================================================
-- 9. COMMIT
-- =============================================================================

COMMIT;