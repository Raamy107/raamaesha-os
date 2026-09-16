-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 072_nandi_capability_gateway_foundation.sql
-- Module    : Nandi Capability Gateway
--
-- Purpose:
--   Creates the durable Nandi control-plane boundary for resolving a planned
--   capability request to an authorized agent-capability binding and a concrete
--   capability-operation binding.
--
-- Architecture:
--
--   058 Agent Invocation
--          |
--          v
--   062 Nandi Plan
--          |
--          v
--   072 Capability Gateway
--          |
--          +--> 052 Agent Capability Binding
--          |
--          +--> 024 Capability Operation Binding
--          |
--          v
--   063 Governance Decision
--          |
--          v
--   064 Execution Dispatch
--          |
--          v
--   Agent Runtime
--
-- Responsibilities:
--   - Durable capability-resolution request records
--   - Planned action identity
--   - Agent capability binding reference
--   - Capability operation binding reference
--   - Gateway resolution lifecycle
--   - Tenant-safe invocation and plan relationships
--   - Resolution integrity validation
--   - Historical resolution records
--   - Non-secret resolution metadata
--
-- Does NOT:
--   - Register capabilities
--   - Register capability APIs/events
--   - Register integration operations
--   - Replace agent capability authorization
--   - Perform governance authorization
--   - Dispatch agent execution
--   - Execute agents
--   - Execute integrations
--   - Store credentials or secrets
--   - Store external request/response payloads
--   - Store AI model-selection decisions
--
-- Existing boundaries:
--   022 Capability Registry
--   023 Capability Interfaces
--   024 Capability Operation Bindings
--   052 Agent Capability Bindings
--   058 Agent Invocations
--   062 Nandi Planning
--   063 Governance Decisions
--   064 Execution Dispatch
--   067 Model Selection
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Gateway Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n
            ON n.oid = t.typnamespace
        WHERE n.nspname = 'raamaesha'
          AND t.typname = 'agent_invocation_capability_gateway_status'
    ) THEN
        CREATE TYPE raamaesha.agent_invocation_capability_gateway_status AS ENUM (
            'requested',
            'resolving',
            'resolved',
            'failed'
        );
    END IF;
END
$$;


COMMENT ON TYPE raamaesha.agent_invocation_capability_gateway_status IS
'Lifecycle state of a Nandi capability-gateway resolution request. Resolved means a valid capability route was established; it does not mean execution occurred.';


-- =============================================================================
-- Capability Gateway Requests
-- =============================================================================

CREATE TABLE raamaesha.agent_invocation_capability_gateway_requests
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id
        UUID
        NOT NULL,

    agent_invocation_id
        UUID
        NOT NULL,

    plan_id
        UUID
        NOT NULL,

    action_sequence
        INTEGER
        NOT NULL,

    action_type
        TEXT
        NOT NULL,

    agent_capability_binding_id
        UUID
        NOT NULL,

    capability_id
        UUID
        NOT NULL,

    capability_operation_binding_id
        UUID
        NOT NULL,

    status
        raamaesha.agent_invocation_capability_gateway_status
        NOT NULL
        DEFAULT 'requested',

    resolution_reason
        TEXT
        NOT NULL,

    resolution_metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    error_code
        TEXT,

    error_message
        TEXT,

    error_metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by
        UUID,

    updated_by
        UUID,

    deleted_at
        TIMESTAMPTZ,

    -- =========================================================================
    -- Primary Key
    -- =========================================================================

    CONSTRAINT pk_agent_invocation_capability_gateway_requests
        PRIMARY KEY (id),

    -- =========================================================================
    -- Organization
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_capability_gateway_requests_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- =========================================================================
    -- Tenant-Safe Invocation
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_capability_gateway_requests_invocation
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- =========================================================================
    -- Tenant-Safe Nandi Plan
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_capability_gateway_requests_plan
        FOREIGN KEY (plan_id, organization_id)
        REFERENCES raamaesha.agent_invocation_plans(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- =========================================================================
    -- Agent Capability Authorization Binding
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_capability_gateway_requests_agent_binding
        FOREIGN KEY (agent_capability_binding_id)
        REFERENCES raamaesha.agent_capability_bindings(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- =========================================================================
    -- Capability Registry
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_capability_gateway_requests_capability
        FOREIGN KEY (capability_id)
        REFERENCES raamaesha.capabilities(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- =========================================================================
    -- Capability Operation Binding
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_capability_gateway_requests_operation_binding
        FOREIGN KEY (capability_operation_binding_id)
        REFERENCES raamaesha.capability_operation_bindings(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    -- =========================================================================
    -- Audit Actors
    -- =========================================================================

    CONSTRAINT fk_agent_invocation_capability_gateway_requests_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_invocation_capability_gateway_requests_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    -- =========================================================================
    -- Action Integrity
    -- =========================================================================

    CONSTRAINT ck_agent_invocation_capability_gateway_requests_action_sequence
        CHECK (action_sequence >= 1),

    CONSTRAINT ck_agent_invocation_capability_gateway_requests_action_type
        CHECK (btrim(action_type) <> ''),

    -- =========================================================================
    -- Resolution Reason
    -- =========================================================================

    CONSTRAINT ck_agent_invocation_capability_gateway_requests_resolution_reason
        CHECK (btrim(resolution_reason) <> ''),

    -- =========================================================================
    -- JSON Integrity
    -- =========================================================================

    CONSTRAINT ck_agent_invocation_capability_gateway_requests_resolution_metadata
        CHECK (
            jsonb_typeof(resolution_metadata) = 'object'
        ),

    CONSTRAINT ck_agent_invocation_capability_gateway_requests_error_metadata
        CHECK (
            jsonb_typeof(error_metadata) = 'object'
        ),

    -- =========================================================================
    -- Error Integrity
    -- =========================================================================

    CONSTRAINT ck_agent_invocation_capability_gateway_requests_error_code
        CHECK (
            error_code IS NULL
            OR btrim(error_code) <> ''
        ),

    CONSTRAINT ck_agent_invocation_capability_gateway_requests_error_message
        CHECK (
            error_message IS NULL
            OR btrim(error_message) <> ''
        ),

    -- =========================================================================
    -- Lifecycle Integrity
    -- =========================================================================

    CONSTRAINT ck_agent_invocation_capability_gateway_requests_lifecycle
        CHECK (
            (
                status IN ('requested', 'resolving', 'resolved')
                AND error_code IS NULL
                AND error_message IS NULL
            )
            OR
            (
                status = 'failed'
                AND error_code IS NOT NULL
                AND error_message IS NOT NULL
            )
        )
);


-- =============================================================================
-- Historical / Lookup Indexes
-- =============================================================================

CREATE INDEX ix_agent_invocation_capability_gateway_requests_invocation
    ON raamaesha.agent_invocation_capability_gateway_requests
        (agent_invocation_id)
    WHERE deleted_at IS NULL;


CREATE INDEX ix_agent_invocation_capability_gateway_requests_plan
    ON raamaesha.agent_invocation_capability_gateway_requests
        (plan_id)
    WHERE deleted_at IS NULL;


CREATE INDEX ix_agent_invocation_capability_gateway_requests_agent_binding
    ON raamaesha.agent_invocation_capability_gateway_requests
        (agent_capability_binding_id)
    WHERE deleted_at IS NULL;


CREATE INDEX ix_agent_invocation_capability_gateway_requests_capability
    ON raamaesha.agent_invocation_capability_gateway_requests
        (capability_id)
    WHERE deleted_at IS NULL;


CREATE INDEX ix_agent_invocation_capability_gateway_requests_operation_binding
    ON raamaesha.agent_invocation_capability_gateway_requests
        (capability_operation_binding_id)
    WHERE deleted_at IS NULL;


CREATE INDEX ix_agent_invocation_capability_gateway_requests_organization_status
    ON raamaesha.agent_invocation_capability_gateway_requests
        (organization_id, status)
    WHERE deleted_at IS NULL;


CREATE INDEX ix_agent_invocation_capability_gateway_requests_action
    ON raamaesha.agent_invocation_capability_gateway_requests
        (agent_invocation_id, action_sequence)
    WHERE deleted_at IS NULL;


-- =============================================================================
-- Updated-At Function
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.set_agent_invocation_capability_gateway_requests_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$function$;


-- =============================================================================
-- Gateway Resolution Integrity
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_agent_invocation_capability_gateway_request_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
DECLARE
    binding_capability_id UUID;
    binding_agent_version_id UUID;
    binding_status public.agent_capability_binding_status;

    operation_capability_id UUID;
    operation_status public.capability_operation_binding_status;
    operation_deleted_at TIMESTAMPTZ;

    capability_status public.capability_status;
    capability_deleted_at TIMESTAMPTZ;

    agent_version_id UUID;
    agent_instance_id UUID;
BEGIN

    -- -------------------------------------------------------------------------
    -- Identity relationships must remain immutable after creation.
    -- -------------------------------------------------------------------------

    IF TG_OP = 'UPDATE' THEN

        IF NEW.organization_id <> OLD.organization_id
           OR NEW.agent_invocation_id <> OLD.agent_invocation_id
           OR NEW.plan_id <> OLD.plan_id
           OR NEW.action_sequence <> OLD.action_sequence
           OR NEW.action_type <> OLD.action_type
           OR NEW.agent_capability_binding_id <> OLD.agent_capability_binding_id
           OR NEW.capability_id <> OLD.capability_id
           OR NEW.capability_operation_binding_id <> OLD.capability_operation_binding_id
        THEN
            RAISE EXCEPTION
                'Capability gateway request identity fields are immutable';
        END IF;

    END IF;


    -- -------------------------------------------------------------------------
    -- Gateway records must be created in requested status.
    -- -------------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN

        IF NEW.status <> 'requested' THEN
            RAISE EXCEPTION
                'Capability gateway request % must be created with requested status',
                NEW.id;
        END IF;

    END IF;


    -- -------------------------------------------------------------------------
    -- Invocation and plan must belong to the same organization.
    -- -------------------------------------------------------------------------

    IF NOT EXISTS (
        SELECT 1
        FROM raamaesha.agent_invocations ai
        WHERE ai.id = NEW.agent_invocation_id
          AND ai.organization_id = NEW.organization_id
          AND ai.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Agent invocation % was not found for organization %',
            NEW.agent_invocation_id,
            NEW.organization_id;
    END IF;


    IF NOT EXISTS (
        SELECT 1
        FROM raamaesha.agent_invocation_plans ap
        WHERE ap.id = NEW.plan_id
          AND ap.organization_id = NEW.organization_id
          AND ap.agent_invocation_id = NEW.agent_invocation_id
          AND ap.status = 'planned'
          AND ap.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Nandi plan % must belong to invocation %, be planned, and be active for organization %',
            NEW.plan_id,
            NEW.agent_invocation_id,
            NEW.organization_id;
    END IF;


    -- -------------------------------------------------------------------------
    -- Agent capability binding must be active and must represent the selected
    -- capability.
    -- -------------------------------------------------------------------------

    SELECT
        acb.capability_id,
        acb.status,
        acb.agent_version_id
    INTO
        binding_capability_id,
        binding_status,
        binding_agent_version_id
    FROM raamaesha.agent_capability_bindings acb
    WHERE acb.id = NEW.agent_capability_binding_id
      AND acb.deleted_at IS NULL;

    IF binding_capability_id IS NULL THEN
        RAISE EXCEPTION
            'Agent capability binding % was not found',
            NEW.agent_capability_binding_id;
    END IF;


    IF binding_status IS DISTINCT FROM 'active'::public.agent_capability_binding_status THEN
        RAISE EXCEPTION
            'Agent capability binding % must be active',
            NEW.agent_capability_binding_id;
    END IF;

    IF binding_capability_id <> NEW.capability_id THEN
        RAISE EXCEPTION
            'Agent capability binding % does not reference capability %',
            NEW.agent_capability_binding_id,
            NEW.capability_id;
    END IF;


    -- -------------------------------------------------------------------------
    -- Capability must be active and not deleted.
    -- -------------------------------------------------------------------------

    SELECT
        c.status,
        c.deleted_at
    INTO
        capability_status,
        capability_deleted_at
    FROM raamaesha.capabilities c
    WHERE c.id = NEW.capability_id;

    IF capability_status IS DISTINCT FROM 'active'::public.capability_status
       OR capability_deleted_at IS NOT NULL
    THEN
        RAISE EXCEPTION
            'Capability % must be active and not deleted for gateway resolution',
            NEW.capability_id;
    END IF;


    -- -------------------------------------------------------------------------
-- Operation binding must resolve to the same capability and must be active.
    -- -------------------------------------------------------------------------

    SELECT
        cob.capability_id,
        cob.status,
        cob.deleted_at
    INTO
        operation_capability_id,
        operation_status,
        operation_deleted_at
    FROM raamaesha.capability_operation_bindings cob
    WHERE cob.id = NEW.capability_operation_binding_id;

    IF operation_capability_id IS NULL THEN
        RAISE EXCEPTION
            'Capability operation binding % was not found',
            NEW.capability_operation_binding_id;
    END IF;


    IF operation_capability_id <> NEW.capability_id THEN
        RAISE EXCEPTION
            'Capability operation binding % does not reference capability %',
            NEW.capability_operation_binding_id,
            NEW.capability_id;
    END IF;


    IF operation_status IS DISTINCT FROM
       'active'::public.capability_operation_binding_status
       OR operation_deleted_at IS NOT NULL
    THEN
        RAISE EXCEPTION
            'Capability operation binding % must be active and not deleted',
            NEW.capability_operation_binding_id;
    END IF;


    -- -------------------------------------------------------------------------
    -- Plan runtime target must correspond to the agent capability binding.
    -- Migration 062 establishes the optional agent instance/version target.
    -- -------------------------------------------------------------------------

    SELECT
        aip.agent_instance_id,
        aip.agent_version_id
    INTO
        agent_instance_id,
        agent_version_id
    FROM raamaesha.agent_invocation_plans aip
    WHERE aip.id = NEW.plan_id
      AND aip.organization_id = NEW.organization_id
      AND aip.deleted_at IS NULL;

    IF agent_instance_id IS NULL
       OR agent_version_id IS NULL
    THEN
        RAISE EXCEPTION
            'Capability gateway request % requires a plan with an agent instance and agent version',
            NEW.id;
    END IF;

    IF agent_version_id <> binding_agent_version_id THEN
        RAISE EXCEPTION
            'Agent capability binding % does not belong to the plan agent version %',
            NEW.agent_capability_binding_id,
            agent_version_id;
    END IF;


    RETURN NEW;
END;
$function$;


-- =============================================================================
-- Gateway Lifecycle Integrity
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_agent_invocation_capability_gateway_request_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
BEGIN

    IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'requested' THEN
            RAISE EXCEPTION
                'Capability gateway request % must begin in requested status',
                NEW.id;
        END IF;

        RETURN NEW;
    END IF;


    IF TG_OP = 'DELETE' THEN

        IF OLD.status IN ('resolved', 'failed') THEN
            RAISE EXCEPTION
                'Terminal capability gateway request % cannot be deleted',
                OLD.id;
        END IF;

        RETURN OLD;
    END IF;


    IF OLD.status IN ('resolved', 'failed') THEN
        RAISE EXCEPTION
            'Terminal capability gateway request % is immutable',
            OLD.id;
    END IF;


    IF OLD.status = 'requested'
       AND NEW.status NOT IN ('requested', 'resolving')
    THEN
        RAISE EXCEPTION
            'Capability gateway request % can only transition from requested to resolving',
            OLD.id;
    END IF;


    IF OLD.status = 'resolving'
       AND NEW.status NOT IN ('resolving', 'resolved', 'failed')
    THEN
        RAISE EXCEPTION
            'Capability gateway request % can only transition from resolving to resolved or failed',
            OLD.id;
    END IF;


    RETURN NEW;
END;
$function$;


-- =============================================================================
-- Updated-At Trigger
-- =============================================================================

CREATE TRIGGER
    trg_agent_invocation_capability_gateway_requests_updated_at
BEFORE UPDATE
ON raamaesha.agent_invocation_capability_gateway_requests
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.set_agent_invocation_capability_gateway_requests_updated_at();


-- =============================================================================
-- Integrity Trigger
-- =============================================================================

CREATE TRIGGER
    trg_agent_invocation_capability_gateway_requests_integrity
BEFORE INSERT OR UPDATE
ON raamaesha.agent_invocation_capability_gateway_requests
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_agent_invocation_capability_gateway_request_integrity();


-- =============================================================================
-- Lifecycle Trigger
-- =============================================================================

CREATE TRIGGER
    trg_agent_invocation_capability_gateway_requests_lifecycle
BEFORE INSERT OR UPDATE OR DELETE
ON raamaesha.agent_invocation_capability_gateway_requests
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_agent_invocation_capability_gateway_request_lifecycle();


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.agent_invocation_capability_gateway_requests IS
'Durable Nandi control-plane records for resolving planned capability actions to authorized agent-capability bindings and concrete capability-operation bindings. Does not perform governance authorization or execution.';


COMMENT ON COLUMN raamaesha.agent_invocation_capability_gateway_requests.agent_capability_binding_id IS
'Agent-version capability authorization binding from migration 052 used as the gateway authorization scope.';


COMMENT ON COLUMN raamaesha.agent_invocation_capability_gateway_requests.capability_id IS
'Platform capability resolved by the gateway. References migration 022.';


COMMENT ON COLUMN raamaesha.agent_invocation_capability_gateway_requests.capability_operation_binding_id IS
'Concrete capability-to-operation route selected by the gateway from migration 024.';


COMMENT ON COLUMN raamaesha.agent_invocation_capability_gateway_requests.status IS
'Gateway resolution lifecycle. Resolved means a valid route was established; it does not indicate governance approval or execution completion.';


COMMENT ON COLUMN raamaesha.agent_invocation_capability_gateway_requests.resolution_metadata IS
'Non-secret structured metadata describing the gateway resolution decision. Credentials and execution payloads must not be stored here.';


COMMENT ON COLUMN raamaesha.agent_invocation_capability_gateway_requests.error_metadata IS
'Structured non-secret metadata describing gateway resolution failure.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;
