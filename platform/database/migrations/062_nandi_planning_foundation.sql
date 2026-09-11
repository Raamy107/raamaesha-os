-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 062_nandi_planning_foundation.sql
-- Module    : Nandi Planning Platform
--
-- Purpose:
--   Records Nandi's structured planning result after context assembly and
--   before governance and agent runtime execution.
--
-- Architecture:
--   Invocation
--      -> Context References
--      -> Context Resolutions
--      -> Context Package
--      -> Planning
--      -> Governance / Authorization
--      -> Agent Run
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. Planning Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_plan_status'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_plan_status AS ENUM (
            'planning',
            'planned',
            'rejected',
            'failed',
            'superseded'
        );
    END IF;
END
$$;

-- =============================================================================
-- 2. Tenant-Safe Parent Key for Context Packages
--
-- Migration 061 created the context package primary key on id only.
-- Migration 062 requires a tenant-safe composite reference.
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'raamaesha.agent_invocation_context_packages'::regclass
          AND conname = 'uq_agent_invocation_context_packages_id_organization'
    ) THEN
        ALTER TABLE raamaesha.agent_invocation_context_packages
            ADD CONSTRAINT uq_agent_invocation_context_packages_id_organization
            UNIQUE (id, organization_id);
    END IF;
END
$$;

-- =============================================================================
-- 3. Planning Table
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.agent_invocation_plans (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    agent_invocation_id UUID NOT NULL,
    context_package_id UUID NOT NULL,
    plan_version INTEGER NOT NULL DEFAULT 1,
    status raamaesha.agent_invocation_plan_status NOT NULL DEFAULT 'planning',

    agent_instance_id UUID NULL,
    agent_version_id UUID NULL,

    model_provider_ref TEXT NULL,
    model_ref TEXT NULL,

    objective TEXT NOT NULL,

    plan_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    plan_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    decision_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    error_code TEXT NULL,
    error_message TEXT NULL,
    error_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by UUID NULL,
    updated_by UUID NULL,
    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT agent_invocation_plans_pkey
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_invocation_plans_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_plans_invocation_organization
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_plans_context_package_organization
        FOREIGN KEY (context_package_id, organization_id)
        REFERENCES raamaesha.agent_invocation_context_packages(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_plans_agent_instance_organization
        FOREIGN KEY (agent_instance_id, organization_id)
        REFERENCES raamaesha.agent_instances(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_plans_agent_instance_version
        FOREIGN KEY (agent_instance_id, agent_version_id)
        REFERENCES raamaesha.agent_instances(id, agent_version_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_plans_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_plans_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_agent_invocation_plans_plan_version
        CHECK (plan_version >= 1),

    CONSTRAINT ck_agent_invocation_plans_objective
        CHECK (length(btrim(objective)) > 0),

    CONSTRAINT ck_agent_invocation_plans_payload_object
        CHECK (jsonb_typeof(plan_payload) = 'object'),

    CONSTRAINT ck_agent_invocation_plans_metadata_object
        CHECK (jsonb_typeof(plan_metadata) = 'object'),

    CONSTRAINT ck_agent_invocation_plans_decision_metadata_object
        CHECK (jsonb_typeof(decision_metadata) = 'object'),

    CONSTRAINT ck_agent_invocation_plans_error_code
        CHECK (
            error_code IS NULL
            OR length(btrim(error_code)) > 0
        ),

    CONSTRAINT ck_agent_invocation_plans_error_message
        CHECK (
            error_message IS NULL
            OR length(btrim(error_message)) > 0
        ),

    CONSTRAINT ck_agent_invocation_plans_error_metadata_object
        CHECK (jsonb_typeof(error_metadata) = 'object'),

    CONSTRAINT ck_agent_invocation_plans_failed_error_code
        CHECK (
            status <> 'failed'
            OR error_code IS NOT NULL
        ),

    CONSTRAINT ck_agent_invocation_plans_agent_pair
        CHECK (
            (agent_instance_id IS NULL AND agent_version_id IS NULL)
            OR
            (agent_instance_id IS NOT NULL AND agent_version_id IS NOT NULL)
        )
);

-- =============================================================================
-- 4. Comments
-- =============================================================================

COMMENT ON TABLE raamaesha.agent_invocation_plans IS
    'Structured Nandi planning results recorded between context assembly and governance/execution.';

COMMENT ON COLUMN raamaesha.agent_invocation_plans.plan_payload IS
    'Structured executable planning representation; must not contain hidden chain-of-thought or private reasoning.';

COMMENT ON COLUMN raamaesha.agent_invocation_plans.plan_metadata IS
    'Non-sensitive metadata describing the planning result.';

COMMENT ON COLUMN raamaesha.agent_invocation_plans.decision_metadata IS
    'Structured decision and evidence metadata; not private reasoning or hidden chain-of-thought.';

COMMENT ON COLUMN raamaesha.agent_invocation_plans.model_provider_ref IS
    'Historical provider identity snapshot selected by the Nandi control plane.';

COMMENT ON COLUMN raamaesha.agent_invocation_plans.model_ref IS
    'Historical model identity snapshot selected by the Nandi control plane.';

-- =============================================================================
-- 5. Indexes
-- =============================================================================

CREATE INDEX IF NOT EXISTS ix_agent_invocation_plans_invocation
    ON raamaesha.agent_invocation_plans (agent_invocation_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_plans_organization_status
    ON raamaesha.agent_invocation_plans (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_plans_invocation_version
    ON raamaesha.agent_invocation_plans (agent_invocation_id, plan_version)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_invocation_plans_active_version
    ON raamaesha.agent_invocation_plans (agent_invocation_id, plan_version)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_plans_agent_instance
    ON raamaesha.agent_invocation_plans (agent_instance_id)
    WHERE deleted_at IS NULL;

-- =============================================================================
-- 6. Updated-at Function
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_agent_invocation_plans_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- 7. Planning Mutability Function
--
-- Terminal plans are immutable.
--
-- Special controlled transition:
--   planned -> superseded
--
-- This allows an already planned version to be explicitly superseded
-- without permitting modification of its planning content.
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_agent_invocation_plans_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        RETURN NEW;
    END IF;

    IF OLD.status IN ('rejected', 'failed', 'superseded') THEN
        RAISE EXCEPTION
            'Agent invocation plan % is immutable because its status is %',
            OLD.id,
            OLD.status;
    END IF;

    IF OLD.status = 'planned' THEN
        IF TG_OP = 'UPDATE'
           AND NEW.status = 'superseded'
           AND NEW.id = OLD.id
           AND NEW.organization_id = OLD.organization_id
           AND NEW.agent_invocation_id = OLD.agent_invocation_id
           AND NEW.context_package_id = OLD.context_package_id
           AND NEW.plan_version = OLD.plan_version
           AND NEW.agent_instance_id IS NOT DISTINCT FROM OLD.agent_instance_id
           AND NEW.agent_version_id IS NOT DISTINCT FROM OLD.agent_version_id
           AND NEW.model_provider_ref IS NOT DISTINCT FROM OLD.model_provider_ref
           AND NEW.model_ref IS NOT DISTINCT FROM OLD.model_ref
           AND NEW.objective = OLD.objective
           AND NEW.plan_payload = OLD.plan_payload
           AND NEW.plan_metadata = OLD.plan_metadata
           AND NEW.decision_metadata = OLD.decision_metadata
           AND NEW.error_code IS NOT DISTINCT FROM OLD.error_code
           AND NEW.error_message IS NOT DISTINCT FROM OLD.error_message
           AND NEW.error_metadata = OLD.error_metadata
           AND NEW.created_at = OLD.created_at
           AND NEW.created_by IS NOT DISTINCT FROM OLD.created_by
           AND NEW.deleted_at IS NOT DISTINCT FROM OLD.deleted_at
        THEN
            RETURN NEW;
        END IF;

        RAISE EXCEPTION
            'Agent invocation plan % is immutable in planned status except for planned-to-superseded transition',
            OLD.id;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Agent invocation plan % cannot be deleted',
            OLD.id;
    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- 8. Triggers
-- =============================================================================

DROP TRIGGER IF EXISTS trg_agent_invocation_plans_updated_at
    ON raamaesha.agent_invocation_plans;

CREATE TRIGGER trg_agent_invocation_plans_updated_at
    BEFORE UPDATE
    ON raamaesha.agent_invocation_plans
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.set_agent_invocation_plans_updated_at();

DROP TRIGGER IF EXISTS trg_agent_invocation_plans_immutability
    ON raamaesha.agent_invocation_plans;

CREATE TRIGGER trg_agent_invocation_plans_immutability
    BEFORE INSERT OR UPDATE OR DELETE
    ON raamaesha.agent_invocation_plans
    FOR EACH ROW
    EXECUTE FUNCTION raamaesha.enforce_agent_invocation_plans_mutability();

-- =============================================================================
-- 9. Commit
-- =============================================================================

COMMIT;
