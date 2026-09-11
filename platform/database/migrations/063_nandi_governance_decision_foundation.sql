-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 063_nandi_governance_decision_foundation.sql
-- Module    : Nandi Governance
--
-- Purpose:
--   Records the platform governance decision for each proposed action
--   produced by the Nandi planning layer.
--
-- Responsibilities:
--   - Governance decision identity and tenant ownership
--   - Plan/action relationship
--   - Authoritative capability-operation binding reference
--   - Risk classification
--   - Structured decision reason and metadata
--   - Approval requirement marker
--   - Terminal decision immutability
--
-- Does NOT:
--   - Execute capabilities or integrations
--   - Duplicate capability or operation registries
--   - Authorize through application-only logic
--   - Store hidden chain-of-thought
--   - Store secrets
--   - Implement human approval records
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Defensive parent key for tenant-safe reference from governance decisions
-- =============================================================================

CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_invocation_plans_id_organization
    ON raamaesha.agent_invocation_plans (id, organization_id);

-- =============================================================================
-- Governance Decision Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_governance_decision_status'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_governance_decision_status AS ENUM (
            'evaluating',
            'allowed',
            'denied',
            'require_approval'
        );
    END IF;
END
$$;

-- =============================================================================
-- Governance Risk Level
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'agent_invocation_governance_risk_level'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_governance_risk_level AS ENUM (
            'low',
            'medium',
            'high',
            'critical'
        );
    END IF;
END
$$;

-- =============================================================================
-- Governance Decision Updated-At Function
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_agent_invocation_governance_decisions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- Governance Decision Mutability Function
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_agent_invocation_governance_decisions_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'DELETE' THEN
        IF OLD.decision IN (
            'allowed',
            'denied',
            'require_approval'
        ) THEN
            RAISE EXCEPTION
                'Terminal governance decision % cannot be deleted',
                OLD.id;
        END IF;

        RETURN OLD;
    END IF;

    IF OLD.decision IN (
        'allowed',
        'denied',
        'require_approval'
    ) THEN
        RAISE EXCEPTION
            'Terminal governance decision % cannot be modified',
            OLD.id;
    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- Governance Decisions
-- =============================================================================

CREATE TABLE raamaesha.agent_invocation_governance_decisions (
    id UUID NOT NULL DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_invocation_id UUID NOT NULL,

    plan_id UUID NOT NULL,

    agent_instance_id UUID NULL,

    agent_version_id UUID NULL,

    action_sequence INTEGER NOT NULL,

    action_type TEXT NOT NULL,

    capability_operation_binding_id UUID NOT NULL,

    decision raamaesha.agent_invocation_governance_decision_status
        NOT NULL DEFAULT 'evaluating',

    risk_level raamaesha.agent_invocation_governance_risk_level
        NOT NULL,

    policy_ref TEXT NULL,

    decision_reason TEXT NOT NULL,

    decision_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    approval_required BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_by UUID NULL,

    updated_by UUID NULL,

    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT pk_agent_invocation_governance_decisions
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_invocation_governance_decisions_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_decisions_invocation
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_decisions_plan
        FOREIGN KEY (plan_id, organization_id)
        REFERENCES raamaesha.agent_invocation_plans(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_decisions_agent_instance
        FOREIGN KEY (agent_instance_id, organization_id)
        REFERENCES raamaesha.agent_instances(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_decisions_agent_version
        FOREIGN KEY (agent_instance_id, agent_version_id)
        REFERENCES raamaesha.agent_instances(id, agent_version_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_decisions_capability_operation_binding
        FOREIGN KEY (capability_operation_binding_id)
        REFERENCES raamaesha.capability_operation_bindings(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_decisions_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_governance_decisions_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_agent_invocation_governance_decisions_action_sequence
        CHECK (action_sequence >= 1),

    CONSTRAINT ck_agent_invocation_governance_decisions_action_type
        CHECK (btrim(action_type) <> ''),

    CONSTRAINT ck_agent_invocation_governance_decisions_policy_ref
        CHECK (
            policy_ref IS NULL
            OR btrim(policy_ref) <> ''
        ),

    CONSTRAINT ck_agent_invocation_governance_decisions_reason
        CHECK (btrim(decision_reason) <> ''),

    CONSTRAINT ck_agent_invocation_governance_decisions_metadata_object
        CHECK (jsonb_typeof(decision_metadata) = 'object'),

    CONSTRAINT ck_agent_invocation_governance_decisions_agent_pair
        CHECK (
            (agent_instance_id IS NULL AND agent_version_id IS NULL)
            OR
            (agent_instance_id IS NOT NULL AND agent_version_id IS NOT NULL)
        ),

    CONSTRAINT ck_agent_invocation_governance_decisions_approval_consistency
        CHECK (
            (
                decision = 'require_approval'
                AND approval_required = TRUE
            )
            OR
            (
                decision <> 'require_approval'
            )
        )
);

-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX ix_agent_invocation_governance_decisions_invocation
    ON raamaesha.agent_invocation_governance_decisions (agent_invocation_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocation_governance_decisions_plan
    ON raamaesha.agent_invocation_governance_decisions (plan_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocation_governance_decisions_organization_decision
    ON raamaesha.agent_invocation_governance_decisions
        (organization_id, decision)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocation_governance_decisions_agent_instance
    ON raamaesha.agent_invocation_governance_decisions (agent_instance_id)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_agent_invocation_governance_decisions_binding
    ON raamaesha.agent_invocation_governance_decisions
        (capability_operation_binding_id)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_agent_invocation_governance_decisions_active_action
    ON raamaesha.agent_invocation_governance_decisions
        (plan_id, action_sequence)
    WHERE deleted_at IS NULL;

-- =============================================================================
-- Triggers
-- =============================================================================

CREATE TRIGGER trg_agent_invocation_governance_decisions_updated_at
BEFORE UPDATE
ON raamaesha.agent_invocation_governance_decisions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_agent_invocation_governance_decisions_updated_at();

CREATE TRIGGER trg_agent_invocation_governance_decisions_immutability
BEFORE INSERT OR UPDATE OR DELETE
ON raamaesha.agent_invocation_governance_decisions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.enforce_agent_invocation_governance_decisions_mutability();

-- =============================================================================
-- Documentation Comments
-- =============================================================================

COMMENT ON TABLE raamaesha.agent_invocation_governance_decisions IS
    'Records platform governance decisions for proposed Nandi plan actions.';

COMMENT ON COLUMN raamaesha.agent_invocation_governance_decisions.capability_operation_binding_id IS
    'Authoritative reference to the registered capability-operation relationship proposed for governance evaluation.';

COMMENT ON COLUMN raamaesha.agent_invocation_governance_decisions.decision_reason IS
    'Structured human-readable governance justification; not hidden model chain-of-thought.';

COMMENT ON COLUMN raamaesha.agent_invocation_governance_decisions.decision_metadata IS
    'Structured governance evidence and metadata; must not contain secrets or hidden chain-of-thought.';

COMMENT ON COLUMN raamaesha.agent_invocation_governance_decisions.approval_required IS
    'Indicates whether the governance decision requires a future human approval workflow.';

COMMIT;
