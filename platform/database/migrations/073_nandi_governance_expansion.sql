-- ============================================================================
-- Migration: 073_nandi_governance_expansion.sql
-- Purpose: Nandi Governance Policy, Versioning, Rules, and Evaluation Evidence
-- Owner: RaamaEsha Technologies
-- Architecture:
--   058 Invocation
--       -> 062 Planning
--       -> 072 Capability Gateway
--       -> 063 Governance Decision
--       -> 073 Governance Policy Evaluation / Evidence
--       -> 064 Execution Dispatch
--
-- Responsibilities:
--   1. Tenant-owned governance policy definitions
--   2. Immutable/versioned governance policy definitions
--   3. Machine-evaluable governance policy rules
--   4. Durable governance evaluation evidence
--
-- Does NOT:
--   - create another governance decision system
--   - execute capabilities or integrations
--   - duplicate capability/operation registries
--   - duplicate agent capability bindings
--   - perform capability gateway resolution
--   - perform execution dispatch
--   - manage Agent Run state
--   - manage Integration Execution state
--   - implement human approval records
--   - store secrets or credentials
--   - store hidden chain-of-thought
--
-- Governance decision authority remains:
--   raamaesha.agent_invocation_governance_decisions (063)
--
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. ENUMS
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'governance_policy_status'
          AND typnamespace = 'raamaesha'::regnamespace
    ) THEN
        CREATE TYPE raamaesha.governance_policy_status AS ENUM (
            'draft',
            'active',
            'disabled',
            'retired'
        );
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'governance_policy_version_status'
          AND typnamespace = 'raamaesha'::regnamespace
    ) THEN
        CREATE TYPE raamaesha.governance_policy_version_status AS ENUM (
            'draft',
            'published',
            'retired'
        );
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'governance_policy_rule_type'
          AND typnamespace = 'raamaesha'::regnamespace
    ) THEN
        CREATE TYPE raamaesha.governance_policy_rule_type AS ENUM(
            'allow',
            'deny',
            'require_approval',
            'risk_threshold',
            'condition'
        );
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'governance_policy_evaluation_result'
          AND typnamespace = 'raamaesha'::regnamespace
    ) THEN
        CREATE TYPE raamaesha.governance_policy_evaluation_result AS ENUM (
            'pass',
            'fail',
            'not_applicable',
            'error'
        );
    END IF;
END
$$;

-- ============================================================================
-- 2. GOVERNANCE POLICIES
-- ============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.governance_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    code CITEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT NULL,
    status raamaesha.governance_policy_status NOT NULL DEFAULT 'draft',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID NULL,
    updated_by UUID NULL,
    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_governance_policies_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT fk_governance_policies_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_governance_policies_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_governance_policies_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_governance_policies_code_nonblank
        CHECK (btrim(code::text) <> ''),

    CONSTRAINT ck_governance_policies_name_nonblank
        CHECK (btrim(name) <> '')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_governance_policies_active_code
    ON raamaesha.governance_policies (organization_id, code)
    WHERE deleted_at IS NULL
      AND status IN ('draft', 'active');

CREATE INDEX IF NOT EXISTS ix_governance_policies_organization_status
    ON raamaesha.governance_policies (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_governance_policies_organization
    ON raamaesha.governance_policies (organization_id)
    WHERE deleted_at IS NULL;

-- ============================================================================
-- 3. GOVERNANCE POLICY VERSIONS
-- ============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.governance_policy_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    governance_policy_id UUID NOT NULL,
    version_number INTEGER NOT NULL,
    status raamaesha.governance_policy_version_status NOT NULL DEFAULT 'draft',
    description TEXT NULL,
    configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
    published_at TIMESTAMPTZ NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID NULL,
    updated_by UUID NULL,
    deleted_at TIMESTAMPTZ NULL,



    CONSTRAINT uq_governance_policy_versions_id_policy
        UNIQUE (id, governance_policy_id),

    CONSTRAINT uq_governance_policy_versions_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT uq_governance_policy_versions_policy_version
        UNIQUE (governance_policy_id, version_number),

    CONSTRAINT fk_governance_policy_versions_policy
        FOREIGN KEY (governance_policy_id, organization_id)
        REFERENCES raamaesha.governance_policies(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_governance_policy_versions_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_governance_policy_versions_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_governance_policy_versions_version_positive
        CHECK (version_number >= 1),

    CONSTRAINT ck_governance_policy_versions_configuration_object
        CHECK (jsonb_typeof(configuration) = 'object'),

    CONSTRAINT ck_governance_policy_versions_published_at
        CHECK (
            (status = 'draft' AND published_at IS NULL)
            OR
            (status IN ('published', 'retired') AND published_at IS NOT NULL)
        )
);


CREATE INDEX IF NOT EXISTS ix_governance_policy_versions_organization
    ON raamaesha.governance_policy_versions (organization_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_governance_policy_versions_policy
    ON raamaesha.governance_policy_versions (governance_policy_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_governance_policy_versions_policy_status
    ON raamaesha.governance_policy_versions
        (governance_policy_id, status)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_governance_policy_versions_active
    ON raamaesha.governance_policy_versions
        (governance_policy_id)
    WHERE deleted_at IS NULL
      AND status = 'published';

-- ============================================================================
-- 4. GOVERNANCE POLICY RULES
-- ============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.governance_policy_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    governance_policy_version_id UUID NOT NULL,
    rule_code CITEXT NOT NULL,
    rule_name TEXT NOT NULL,
    description TEXT NULL,
    rule_type raamaesha.governance_policy_rule_type NOT NULL,
    evaluation_order INTEGER NOT NULL DEFAULT 1,
    risk_level raamaesha.agent_invocation_governance_risk_level NOT NULL DEFAULT 'low',
    configuration JSONB NOT NULL DEFAULT '{}'::jsonb,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID NULL,
    updated_by UUID NULL,
    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_governance_policy_rules_id_version
        UNIQUE (id, governance_policy_version_id),

    CONSTRAINT uq_governance_policy_rules_version_code
        UNIQUE (governance_policy_version_id, rule_code),

    CONSTRAINT fk_governance_policy_rules_version
        FOREIGN KEY (governance_policy_version_id, organization_id)
        REFERENCES raamaesha.governance_policy_versions(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_governance_policy_rules_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_governance_policy_rules_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_governance_policy_rules_code_nonblank
        CHECK (btrim(rule_code::text) <> ''),

    CONSTRAINT ck_governance_policy_rules_name_nonblank
        CHECK (btrim(rule_name) <> ''),

    CONSTRAINT ck_governance_policy_rules_evaluation_order_positive
        CHECK (evaluation_order >= 1),

    CONSTRAINT ck_governance_policy_rules_configuration_object
        CHECK (jsonb_typeof(configuration) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_governance_policy_rules_organization
    ON raamaesha.governance_policy_rules (organization_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_governance_policy_rules_version_order
    ON raamaesha.governance_policy_rules
        (governance_policy_version_id, evaluation_order)
    WHERE deleted_at IS NULL
      AND enabled = TRUE;

CREATE INDEX IF NOT EXISTS ix_governance_policy_rules_version_type
    ON raamaesha.governance_policy_rules
        (governance_policy_version_id, rule_type)
    WHERE deleted_at IS NULL
      AND enabled = TRUE;

-- ============================================================================
-- 5. GOVERNANCE POLICY EVALUATION EVIDENCE
-- ============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.agent_invocation_governance_evaluations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,
    governance_decision_id UUID NOT NULL,
    governance_policy_id UUID NOT NULL,
    governance_policy_version_id UUID NOT NULL,
    governance_policy_rule_id UUID NULL,
    evaluation_sequence INTEGER NOT NULL,
    evaluation_result raamaesha.governance_policy_evaluation_result NOT NULL,
    risk_level raamaesha.agent_invocation_governance_risk_level NOT NULL,
    risk_contribution INTEGER NOT NULL DEFAULT 0,
    evaluation_reason TEXT NOT NULL,
    evaluation_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by UUID NULL,
    updated_by UUID NULL,
    deleted_at TIMESTAMPTZ NULL,

    CONSTRAINT uq_agent_invocation_governance_evaluations_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT fk_agent_invocation_governance_evaluations_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_evaluations_decision
        FOREIGN KEY (governance_decision_id, organization_id)
        REFERENCES raamaesha.agent_invocation_governance_decisions(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_evaluations_policy
        FOREIGN KEY (governance_policy_id, organization_id)
        REFERENCES raamaesha.governance_policies(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_evaluations_version
        FOREIGN KEY (governance_policy_version_id, governance_policy_id)
        REFERENCES raamaesha.governance_policy_versions(id, governance_policy_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_evaluations_rule
        FOREIGN KEY (governance_policy_rule_id, governance_policy_version_id)
        REFERENCES raamaesha.governance_policy_rules(id, governance_policy_version_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_governance_evaluations_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_governance_evaluations_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT ck_agent_invocation_governance_evaluations_sequence_positive
        CHECK (evaluation_sequence >= 1),

    CONSTRAINT ck_agent_invocation_governance_evaluations_risk_contribution
        CHECK (risk_contribution >= 0),

    CONSTRAINT ck_agent_invocation_governance_evaluations_reason_nonblank
        CHECK (btrim(evaluation_reason) <> ''),

    CONSTRAINT ck_agent_invocation_governance_evaluations_metadata_object
        CHECK (jsonb_typeof(evaluation_metadata) = 'object')
);

CREATE INDEX IF NOT EXISTS ix_agent_invocation_governance_evaluations_decision
    ON raamaesha.agent_invocation_governance_evaluations
        (governance_decision_id, evaluation_sequence)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_governance_evaluations_policy
    ON raamaesha.agent_invocation_governance_evaluations
        (organization_id, governance_policy_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_governance_evaluations_version
    ON raamaesha.agent_invocation_governance_evaluations
        (governance_policy_version_id)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS ix_agent_invocation_governance_evaluations_result
    ON raamaesha.agent_invocation_governance_evaluations
        (organization_id, evaluation_result)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_invocation_governance_evaluations_sequence
    ON raamaesha.agent_invocation_governance_evaluations
        (governance_decision_id, evaluation_sequence)
    WHERE deleted_at IS NULL;

-- ============================================================================
-- 6. UPDATED_AT FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_governance_policies_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION raamaesha.set_governance_policy_versions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION raamaesha.set_governance_policy_rules_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION raamaesha.set_agent_invocation_governance_evaluations_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$function$;

-- ============================================================================
-- 7. POLICY VERSION IMMUTABILITY
-- ============================================================================

-- ============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_governance_policy_versions_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    IF OLD.status IN ('published', 'retired') THEN

        IF OLD.status = 'published'
           AND NEW.status NOT IN ('published', 'retired')
        THEN
            RAISE EXCEPTION
                'Published governance policy versions may only remain published or transition to retired'
                USING ERRCODE = '55000';
        END IF;

        IF OLD.status = 'retired'
           AND NEW.status <> 'retired'
        THEN
            RAISE EXCEPTION
                'Retired governance policy versions cannot change lifecycle status'
                USING ERRCODE = '55000';
        END IF;

        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION
                'Published or retired governance policy versions cannot be deleted'
                USING ERRCODE = '55000';
        END IF;

        IF NEW.governance_policy_id IS DISTINCT FROM OLD.governance_policy_id
           OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
           OR NEW.version_number IS DISTINCT FROM OLD.version_number
           OR NEW.description IS DISTINCT FROM OLD.description
           OR NEW.configuration IS DISTINCT FROM OLD.configuration
           OR NEW.published_at IS DISTINCT FROM OLD.published_at
           OR NEW.created_by IS DISTINCT FROM OLD.created_by
           OR NEW.created_at IS DISTINCT FROM OLD.created_at
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
        THEN
            RAISE EXCEPTION
                'Published or retired governance policy versions are structurally immutable'
                USING ERRCODE = '55000';
        END IF;

    END IF;

    RETURN NEW;
END;
$function$;
-- 8. POLICY RULE IMMUTABILITY WHEN VERSION IS PUBLISHED/RETIRED
-- ============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_governance_policy_rules_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    v_version_status raamaesha.governance_policy_version_status;
BEGIN
    SELECT status
    INTO v_version_status
    FROM raamaesha.governance_policy_versions
    WHERE id = OLD.governance_policy_version_id
      AND organization_id = OLD.organization_id
      AND deleted_at IS NULL;

    IF v_version_status IN ('published', 'retired') THEN

        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION
                'Rules belonging to published or retired governance policy versions cannot be deleted'
                USING ERRCODE = '55000';
        END IF;

        IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
           OR NEW.governance_policy_version_id IS DISTINCT FROM OLD.governance_policy_version_id
           OR NEW.rule_code IS DISTINCT FROM OLD.rule_code
           OR NEW.rule_name IS DISTINCT FROM OLD.rule_name
           OR NEW.description IS DISTINCT FROM OLD.description
           OR NEW.rule_type IS DISTINCT FROM OLD.rule_type
           OR NEW.evaluation_order IS DISTINCT FROM OLD.evaluation_order
           OR NEW.risk_level IS DISTINCT FROM OLD.risk_level
           OR NEW.configuration IS DISTINCT FROM OLD.configuration
           OR NEW.enabled IS DISTINCT FROM OLD.enabled
           OR NEW.created_by IS DISTINCT FROM OLD.created_by
           OR NEW.created_at IS DISTINCT FROM OLD.created_at
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
        THEN
            RAISE EXCEPTION
                'Rules belonging to published or retired governance policy versions are immutable'
                USING ERRCODE = '55000';
        END IF;

    END IF;

    RETURN NEW;
END;
$function$;

-- ============================================================================
-- 9. GOVERNANCE EVALUATION IMMUTABILITY
-- ============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_agent_invocation_governance_evaluations_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    RAISE EXCEPTION
        'Immutable governance evaluation evidence cannot be %',
        TG_OP
        USING ERRCODE = '55000';

    RETURN NULL;
END;
$function$;

-- ============================================================================
-- 10. TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS trg_governance_policies_updated_at
    ON raamaesha.governance_policies;

CREATE TRIGGER trg_governance_policies_updated_at
BEFORE UPDATE ON raamaesha.governance_policies
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_governance_policies_updated_at();

DROP TRIGGER IF EXISTS trg_governance_policy_versions_updated_at
    ON raamaesha.governance_policy_versions;

CREATE TRIGGER trg_governance_policy_versions_updated_at
BEFORE UPDATE ON raamaesha.governance_policy_versions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_governance_policy_versions_updated_at();

DROP TRIGGER IF EXISTS trg_governance_policy_versions_mutability
    ON raamaesha.governance_policy_versions;

CREATE TRIGGER trg_governance_policy_versions_mutability
BEFORE UPDATE OR DELETE ON raamaesha.governance_policy_versions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.enforce_governance_policy_versions_mutability();

DROP TRIGGER IF EXISTS trg_governance_policy_rules_updated_at
    ON raamaesha.governance_policy_rules;

CREATE TRIGGER trg_governance_policy_rules_updated_at
BEFORE UPDATE ON raamaesha.governance_policy_rules
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_governance_policy_rules_updated_at();

DROP TRIGGER IF EXISTS trg_governance_policy_rules_mutability
    ON raamaesha.governance_policy_rules;

CREATE TRIGGER trg_governance_policy_rules_mutability
BEFORE UPDATE OR DELETE ON raamaesha.governance_policy_rules
FOR EACH ROW
EXECUTE FUNCTION raamaesha.enforce_governance_policy_rules_mutability();

DROP TRIGGER IF EXISTS trg_agent_invocation_governance_evaluations_updated_at
    ON raamaesha.agent_invocation_governance_evaluations;

CREATE TRIGGER trg_agent_invocation_governance_evaluations_updated_at
BEFORE UPDATE ON raamaesha.agent_invocation_governance_evaluations
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_agent_invocation_governance_evaluations_updated_at();

DROP TRIGGER IF EXISTS trg_agent_invocation_governance_evaluations_mutability
    ON raamaesha.agent_invocation_governance_evaluations;

CREATE TRIGGER trg_agent_invocation_governance_evaluations_mutability
BEFORE UPDATE OR DELETE ON raamaesha.agent_invocation_governance_evaluations
FOR EACH ROW
EXECUTE FUNCTION raamaesha.enforce_agent_invocation_governance_evaluations_mutability();

COMMIT;
