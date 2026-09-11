-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 064_nandi_execution_dispatch_foundation.sql
-- Module    : Nandi Execution Dispatch
--
-- Purpose:
--   Records the durable handoff of an approved Nandi governance decision
--   into the Agent Runtime.
--
-- Responsibilities:
--   - Governance decision to runtime dispatch boundary
--   - Dispatch attempt history
--   - One active dispatch attempt per governance decision
--   - Agent Run acceptance reference
--   - Dispatch lifecycle integrity
--   - Tenant-safe relationships
--
-- Does NOT:
--   - Execute agents
--   - Execute integrations
--   - Duplicate capability or operation registries
--   - Duplicate Agent Run or Run Step state
--   - Store secrets
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Defensive Parent Key
-- =============================================================================

-- 063 has a primary key on id but does not expose the tenant-safe
-- (id, organization_id) parent key required by this migration.
CREATE UNIQUE INDEX IF NOT EXISTS
    uq_agent_invocation_governance_decisions_id_organization
    ON raamaesha.agent_invocation_governance_decisions (
        id,
        organization_id
    );

-- =============================================================================
-- Dispatch Status
-- =============================================================================

CREATE TYPE raamaesha.agent_invocation_execution_dispatch_status AS ENUM (
    'pending',
    'dispatched',
    'accepted',
    'failed'
);

-- =============================================================================
-- Execution Dispatches
-- =============================================================================

CREATE TABLE raamaesha.agent_invocation_execution_dispatches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_invocation_id UUID NOT NULL,

    governance_decision_id UUID NOT NULL,

    plan_id UUID NOT NULL,

    agent_instance_id UUID NOT NULL,

    agent_version_id UUID NOT NULL,

    agent_run_id UUID NULL,

    attempt_no INTEGER NOT NULL DEFAULT 1,

    status raamaesha.agent_invocation_execution_dispatch_status
        NOT NULL DEFAULT 'pending',

    dispatched_at TIMESTAMPTZ NULL,

    accepted_at TIMESTAMPTZ NULL,

    error_code TEXT NULL,

    error_message TEXT NULL,

    error_metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    created_by UUID NULL,

    updated_by UUID NULL,

    deleted_at TIMESTAMPTZ NULL,

    -- =========================================================================
    -- Tenant Integrity
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_execution_dispatches_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_execution_dispatches_invocation
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_execution_dispatches_governance
        FOREIGN KEY (governance_decision_id, organization_id)
        REFERENCES raamaesha.agent_invocation_governance_decisions(
            id,
            organization_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_execution_dispatches_plan
        FOREIGN KEY (plan_id, organization_id)
        REFERENCES raamaesha.agent_invocation_plans(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- =========================================================================
    -- Agent Runtime Integrity
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_execution_dispatches_agent_instance
        FOREIGN KEY (agent_instance_id, organization_id)
        REFERENCES raamaesha.agent_instances(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_execution_dispatches_agent_version
        FOREIGN KEY (agent_instance_id, agent_version_id)
        REFERENCES raamaesha.agent_instances(id, agent_version_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_invocation_execution_dispatches_agent_run
        FOREIGN KEY (agent_run_id, organization_id)
        REFERENCES raamaesha.agent_runs(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- =========================================================================
    -- Audit Integrity
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_execution_dispatches_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_execution_dispatches_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    -- =========================================================================
    -- Basic Validation
    -- =========================================================================

    CONSTRAINT ck_agent_invocation_execution_dispatches_attempt_positive
        CHECK (attempt_no >= 1),

    CONSTRAINT ck_agent_invocation_execution_dispatches_error_code
        CHECK (
            error_code IS NULL
            OR btrim(error_code) <> ''
        ),

    CONSTRAINT ck_agent_invocation_execution_dispatches_error_message
        CHECK (
            error_message IS NULL
            OR btrim(error_message) <> ''
        ),

    CONSTRAINT ck_agent_invocation_execution_dispatches_error_metadata_object
        CHECK (
            jsonb_typeof(error_metadata) = 'object'
        ),

    CONSTRAINT ck_agent_invocation_execution_dispatches_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        ),

    -- =========================================================================
    -- Dispatch Lifecycle
    -- =========================================================================

    CONSTRAINT ck_agent_invocation_execution_dispatches_lifecycle
        CHECK (
            (
                status = 'pending'
                AND dispatched_at IS NULL
                AND accepted_at IS NULL
                AND agent_run_id IS NULL
            )
            OR
            (
                status = 'dispatched'
                AND dispatched_at IS NOT NULL
                AND accepted_at IS NULL
                AND agent_run_id IS NULL
            )
            OR
            (
                status = 'accepted'
                AND dispatched_at IS NOT NULL
                AND accepted_at IS NOT NULL
                AND agent_run_id IS NOT NULL
            )
            OR
            (
                status = 'failed'
                AND dispatched_at IS NOT NULL
                AND accepted_at IS NULL
                AND agent_run_id IS NULL
            )
        ),

    CONSTRAINT ck_agent_invocation_execution_dispatches_accept_after_dispatch
        CHECK (
            accepted_at IS NULL
            OR dispatched_at IS NULL
            OR accepted_at >= dispatched_at
        ),

    CONSTRAINT ck_agent_invocation_execution_dispatches_failed_error
        CHECK (
            status <> 'failed'
            OR error_code IS NOT NULL
        )
);

-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX
    ix_agent_invocation_execution_dispatches_invocation
    ON raamaesha.agent_invocation_execution_dispatches (
        agent_invocation_id
    )
    WHERE deleted_at IS NULL;

CREATE INDEX
    ix_agent_invocation_execution_dispatches_governance
    ON raamaesha.agent_invocation_execution_dispatches (
        governance_decision_id
    )
    WHERE deleted_at IS NULL;

CREATE INDEX
    ix_agent_invocation_execution_dispatches_plan
    ON raamaesha.agent_invocation_execution_dispatches (
        plan_id
    )
    WHERE deleted_at IS NULL;

CREATE INDEX
    ix_agent_invocation_execution_dispatches_organization_status
    ON raamaesha.agent_invocation_execution_dispatches (
        organization_id,
        status
    )
    WHERE deleted_at IS NULL;

CREATE INDEX
    ix_agent_invocation_execution_dispatches_agent_run
    ON raamaesha.agent_invocation_execution_dispatches (
        agent_run_id
    )
    WHERE deleted_at IS NULL;

CREATE INDEX
    ix_agent_invocation_execution_dispatches_agent_instance
    ON raamaesha.agent_invocation_execution_dispatches (
        agent_instance_id
    )
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX
    uq_agent_invocation_execution_dispatches_active_attempt
    ON raamaesha.agent_invocation_execution_dispatches (
        governance_decision_id
    )
    WHERE deleted_at IS NULL
      AND status IN ('pending', 'dispatched');

CREATE UNIQUE INDEX
    uq_agent_invocation_execution_dispatches_attempt
    ON raamaesha.agent_invocation_execution_dispatches (
        governance_decision_id,
        attempt_no
    )
    WHERE deleted_at IS NULL;

-- =============================================================================
-- Updated-At Function
-- =============================================================================

CREATE FUNCTION
    raamaesha.set_agent_invocation_execution_dispatches_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$function$;

-- =============================================================================
-- Mutability Function
-- =============================================================================

CREATE FUNCTION
    raamaesha.enforce_agent_invocation_execution_dispatches_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    governance_status raamaesha.agent_invocation_governance_decision_status;
    governance_invocation_id UUID;
    governance_plan_id UUID;
    governance_agent_instance_id UUID;
    governance_agent_version_id UUID;
    run_organization_id UUID;
    run_agent_instance_id UUID;
    run_agent_version_id UUID;
    accepted_dispatch_exists BOOLEAN;
BEGIN
    -- -------------------------------------------------------------------------
    -- INSERT
    -- -------------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN

        IF NEW.status <> 'pending' THEN
            RAISE EXCEPTION
                'Execution dispatch must be created with status pending';
        END IF;

        SELECT
            decision,
            agent_invocation_id,
            plan_id,
            agent_instance_id,
            agent_version_id
        INTO
            governance_status,
            governance_invocation_id,
            governance_plan_id,
            governance_agent_instance_id,
            governance_agent_version_id
        FROM raamaesha.agent_invocation_governance_decisions
        WHERE id = NEW.governance_decision_id
          AND organization_id = NEW.organization_id
          AND deleted_at IS NULL;

        IF governance_status IS NULL THEN
            RAISE EXCEPTION
                'Governance decision % was not found for organization %',
                NEW.governance_decision_id,
                NEW.organization_id;
        END IF;

        IF governance_status <> 'allowed' THEN
            RAISE EXCEPTION
                'Execution dispatch requires an allowed governance decision; current status is %',
                governance_status;
        END IF;

        IF governance_invocation_id <> NEW.agent_invocation_id THEN
            RAISE EXCEPTION
                'Execution dispatch invocation does not match governance decision %',
                NEW.governance_decision_id;
        END IF;

        IF governance_plan_id <> NEW.plan_id THEN
            RAISE EXCEPTION
                'Execution dispatch plan does not match governance decision %',
                NEW.governance_decision_id;
        END IF;

        IF governance_agent_instance_id IS NULL
           OR governance_agent_version_id IS NULL THEN
            RAISE EXCEPTION
                'Governance decision % does not contain a concrete agent runtime target',
                NEW.governance_decision_id;
        END IF;

        IF governance_agent_instance_id <> NEW.agent_instance_id
           OR governance_agent_version_id <> NEW.agent_version_id THEN
            RAISE EXCEPTION
                'Execution dispatch agent target does not match governance decision %',
                NEW.governance_decision_id;
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM raamaesha.agent_invocation_execution_dispatches
            WHERE governance_decision_id = NEW.governance_decision_id
              AND organization_id = NEW.organization_id
              AND status = 'accepted'
              AND deleted_at IS NULL
        )
        INTO accepted_dispatch_exists;

        IF accepted_dispatch_exists THEN
            RAISE EXCEPTION
                'Governance decision % already has an accepted execution dispatch',
                NEW.governance_decision_id;
        END IF;

        RETURN NEW;
    END IF;

    -- -------------------------------------------------------------------------
    -- DELETE
    -- -------------------------------------------------------------------------

    IF TG_OP = 'DELETE' THEN
        IF OLD.status IN ('accepted', 'failed') THEN
            RAISE EXCEPTION
                'Terminal execution dispatch records cannot be deleted';
        END IF;

        RETURN OLD;
    END IF;

    -- -------------------------------------------------------------------------
    -- UPDATE
    -- -------------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN

        IF OLD.status IN ('accepted', 'failed') THEN
            RAISE EXCEPTION
                'Terminal execution dispatch records are immutable';
        END IF;

        -- Pending can only become dispatched.
        IF OLD.status = 'pending'
           AND NEW.status <> 'dispatched' THEN
            RAISE EXCEPTION
                'Pending execution dispatch can only transition to dispatched';
        END IF;

        -- Dispatched can only become accepted or failed.
        IF OLD.status = 'dispatched'
           AND NEW.status NOT IN ('accepted', 'failed') THEN
            RAISE EXCEPTION
                'Dispatched execution dispatch can only transition to accepted or failed';
        END IF;

        -- Dispatch identity is immutable.
        IF NEW.organization_id <> OLD.organization_id
           OR NEW.agent_invocation_id <> OLD.agent_invocation_id
           OR NEW.governance_decision_id <> OLD.governance_decision_id
           OR NEW.plan_id <> OLD.plan_id
           OR NEW.agent_instance_id <> OLD.agent_instance_id
           OR NEW.agent_version_id <> OLD.agent_version_id
           OR NEW.attempt_no <> OLD.attempt_no THEN
            RAISE EXCEPTION
                'Execution dispatch identity fields are immutable';
        END IF;

        -- Accepted dispatches must point to a matching Agent Runtime run.
        IF NEW.status = 'accepted' THEN

            IF NEW.agent_run_id IS NULL THEN
                RAISE EXCEPTION
                    'Accepted execution dispatch requires an agent run';
            END IF;

            SELECT
                organization_id,
                agent_instance_id,
                agent_version_id
            INTO
                run_organization_id,
                run_agent_instance_id,
                run_agent_version_id
            FROM raamaesha.agent_runs
            WHERE id = NEW.agent_run_id
              AND organization_id = NEW.organization_id
              AND deleted_at IS NULL;

            IF run_organization_id IS NULL THEN
                RAISE EXCEPTION
                    'Agent run % was not found for organization %',
                    NEW.agent_run_id,
                    NEW.organization_id;
            END IF;

            IF run_agent_instance_id <> NEW.agent_instance_id
               OR run_agent_version_id <> NEW.agent_version_id THEN
                RAISE EXCEPTION
                    'Accepted execution dispatch agent run does not match the dispatch runtime target';
            END IF;
        END IF;

        -- A dispatch may not be redirected to a different governance decision
        -- or runtime target.
        RETURN NEW;
    END IF;

    RETURN NEW;
END;
$function$;
-- =============================================================================
-- Triggers
-- =============================================================================

CREATE TRIGGER
    trg_agent_invocation_execution_dispatches_updated_at
BEFORE UPDATE
ON raamaesha.agent_invocation_execution_dispatches
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.set_agent_invocation_execution_dispatches_updated_at();

CREATE TRIGGER
    trg_agent_invocation_execution_dispatches_immutability
BEFORE INSERT OR UPDATE OR DELETE
ON raamaesha.agent_invocation_execution_dispatches
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_agent_invocation_execution_dispatches_mutability();

-- =============================================================================
-- Documentation Comments
-- =============================================================================

COMMENT ON TABLE raamaesha.agent_invocation_execution_dispatches IS
'Durable handoff records from allowed Nandi governance decisions into Agent Runtime. Does not execute agents or integrations.';

COMMENT ON COLUMN raamaesha.agent_invocation_execution_dispatches.attempt_no IS
'Monotonic dispatch attempt number for a governance decision. Failed attempts remain historical.';

COMMENT ON COLUMN raamaesha.agent_invocation_execution_dispatches.agent_run_id IS
'Agent Runtime run accepted for this dispatch. NULL until dispatch status becomes accepted.';

COMMENT ON COLUMN raamaesha.agent_invocation_execution_dispatches.metadata IS
'Non-secret operational metadata for the dispatch boundary.';

COMMENT ON COLUMN raamaesha.agent_invocation_execution_dispatches.error_metadata IS
'Structured non-secret metadata describing dispatch failure.';

COMMIT;
