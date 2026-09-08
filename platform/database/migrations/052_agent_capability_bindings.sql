-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 052_agent_capability_bindings.sql
-- Module    : Agent Capability Binding
--
-- Purpose:
--   Creates the persistent binding layer between versioned AI agents and
--   reusable platform capabilities.
--
-- Responsibilities:
--   - Agent version to capability relationships
--   - Binding lifecycle management
--   - Non-secret binding configuration
--   - Published agent-version composition integrity
--   - Capability lifecycle integrity
--   - Audit actor references
--   - Soft deletion
--   - Active capability discovery
--
-- Architecture:
--
--   Agent Definition
--          |
--          v
--   Agent Version
--          |
--          v
--   Agent Capability Binding
--          |
--          v
--   Platform Capability
--          |
--          v
--   Capability Operation Binding
--          |
--          v
--   Integration Operation
--          |
--          v
--   Integration
--
-- Design Principles:
--   - Capabilities remain platform-level and reusable
--   - Agents consume capabilities through explicit bindings
--   - No duplicated tool registry
--   - No authorization logic
--   - No execution logic
--   - No integration execution logic
--   - No secrets
--   - Published agent versions have immutable capability composition
--   - Soft deletion supported
--   - Audit actor references supported
--   - Compatible with future Tool Gateway and Nandi AI runtime
--
-- Dependencies:
--   - 001_extensions.sql
--   - 003_schema_core.sql
--   - 007_identity_actor.sql
--   - 013_audit_infrastructure.sql
--   - 022_capability_registry.sql
--   - 051_agent_foundation.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- ENUM : Agent Capability Binding Status
-- =============================================================================

CREATE TYPE public.agent_capability_binding_status AS ENUM
(
    'draft',
    'active',
    'disabled',
    'deprecated'
);

COMMENT ON TYPE public.agent_capability_binding_status IS
'Lifecycle state of an agent-version capability binding.';


-- =============================================================================
-- Agent Capability Bindings
-- =============================================================================
--
-- Represents one explicit capability assignment to one versioned AI agent.
--
-- Capabilities are platform-level reusable definitions. The binding therefore
-- does not duplicate organization_id. Tenant context is inherited through the
-- owning agent version and its agent definition.
--
-- Binding configuration contains non-secret runtime/discovery metadata only.
-- Credentials, tokens, secrets, and execution payloads remain outside this
-- table.
-- =============================================================================

CREATE TABLE raamaesha.agent_capability_bindings
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    agent_version_id
        UUID
        NOT NULL,

    capability_id
        UUID
        NOT NULL,

    status
        public.agent_capability_binding_status
        NOT NULL
        DEFAULT 'draft',

    configuration
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

    CONSTRAINT pk_agent_capability_bindings
        PRIMARY KEY (id),


    -- =========================================================================
    -- Agent Version Relationship
    -- =========================================================================

    CONSTRAINT fk_agent_capability_bindings_agent_version
        FOREIGN KEY (agent_version_id)
        REFERENCES raamaesha.agent_versions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Capability Relationship
    -- =========================================================================

    CONSTRAINT fk_agent_capability_bindings_capability
        FOREIGN KEY (capability_id)
        REFERENCES raamaesha.capabilities(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Audit Actor Relationships
    -- =========================================================================

    CONSTRAINT fk_agent_capability_bindings_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_agent_capability_bindings_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- Binding Identity
    -- =========================================================================
    --
    -- Prevents duplicate current bindings. Historical soft-deleted bindings
    -- are handled by the production partial unique index below.
    -- =========================================================================



    -- =========================================================================
    -- Configuration Integrity
    -- =========================================================================

    CONSTRAINT ck_agent_capability_bindings_configuration_object
        CHECK (
            jsonb_typeof(configuration) = 'object'
        )

);


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.agent_capability_bindings IS
'Explicit capability assignments for versioned RaamaEsha OS AI agents.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.id IS
'Globally unique identifier for the agent capability binding.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.agent_version_id IS
'Versioned agent that receives this capability binding.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.capability_id IS
'Reusable platform capability assigned to the agent version.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.status IS
'Lifecycle state of the agent capability binding.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.configuration IS
'Extensible non-secret binding configuration. Plaintext credentials, tokens, and secrets must not be stored here.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.created_at IS
'Timestamp when the agent capability binding was created.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.updated_at IS
'Timestamp when the agent capability binding was most recently updated.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.created_by IS
'Actor responsible for creating the binding when known.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.updated_by IS
'Actor responsible for the most recent binding update when known.';


COMMENT ON COLUMN raamaesha.agent_capability_bindings.deleted_at IS
'Soft deletion timestamp. NULL indicates that the binding has not been soft deleted.';


-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX idx_agent_capability_bindings_agent_version
    ON raamaesha.agent_capability_bindings (agent_version_id);


CREATE INDEX idx_agent_capability_bindings_capability
    ON raamaesha.agent_capability_bindings (capability_id);


CREATE INDEX idx_agent_capability_bindings_status
    ON raamaesha.agent_capability_bindings (status);


CREATE INDEX idx_agent_capability_bindings_deleted_at
    ON raamaesha.agent_capability_bindings (deleted_at);


-- =============================================================================
-- Active Capability Discovery
-- =============================================================================

CREATE INDEX idx_agent_capability_bindings_active_discovery
    ON raamaesha.agent_capability_bindings
    (
        agent_version_id,
        capability_id
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Production Integrity : One Current Binding
-- =============================================================================
--
-- Ensures an agent version cannot have two current bindings to the same
-- capability.
-- =============================================================================

CREATE UNIQUE INDEX ux_agent_capability_bindings_one_current
    ON raamaesha.agent_capability_bindings
    (
        agent_version_id,
        capability_id
    )
    WHERE deleted_at IS NULL;


-- =============================================================================
-- Lifecycle Function
-- =============================================================================
--
-- Binding lifecycle:
--
--   draft     -> active
--   draft     -> disabled
--   active    -> disabled
--   active    -> deprecated
--   disabled  -> active
--   disabled  -> deprecated
--
-- Deprecated is terminal.
--
-- A binding cannot become active unless its capability is currently active
-- and not soft deleted.
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_agent_capability_binding_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    capability_current_status public.capability_status;
    capability_deleted_at TIMESTAMPTZ;
BEGIN

    IF TG_OP = 'INSERT' THEN

        IF NEW.status = 'active' THEN

            SELECT
                c.status,
                c.deleted_at
            INTO
                capability_current_status,
                capability_deleted_at
            FROM raamaesha.capabilities AS c
            WHERE c.id = NEW.capability_id;

            IF capability_current_status IS DISTINCT FROM 'active'::public.capability_status
               OR capability_deleted_at IS NOT NULL
            THEN
                RAISE EXCEPTION
                    'Agent capability binding cannot be active unless capability % is active and not deleted',
                    NEW.capability_id;
            END IF;

        END IF;

        RETURN NEW;
    END IF;


    IF OLD.status = 'deprecated'
       AND NEW.status IS DISTINCT FROM OLD.status
    THEN
        RAISE EXCEPTION
            'Deprecated agent capability binding % cannot change lifecycle state',
            OLD.id;
    END IF;


    IF OLD.status = 'draft'
       AND NEW.status NOT IN
           (
               'draft',
               'active',
               'disabled'
           )
    THEN
        RAISE EXCEPTION
            'Invalid agent capability binding lifecycle transition from % to %',
            OLD.status,
            NEW.status;
    END IF;


    IF OLD.status = 'active'
       AND NEW.status NOT IN
           (
               'active',
               'disabled',
               'deprecated'
           )
    THEN
        RAISE EXCEPTION
            'Invalid agent capability binding lifecycle transition from % to %',
            OLD.status,
            NEW.status;
    END IF;


    IF OLD.status = 'disabled'
       AND NEW.status NOT IN
           (
               'disabled',
               'active',
               'deprecated'
           )
    THEN
        RAISE EXCEPTION
            'Invalid agent capability binding lifecycle transition from % to %',
            OLD.status,
            NEW.status;
    END IF;


    IF NEW.status = 'active'
       AND (
            NEW.capability_id IS DISTINCT FROM OLD.capability_id
            OR OLD.status IS DISTINCT FROM 'active'::public.agent_capability_binding_status
       )
    THEN

        SELECT
            c.status,
            c.deleted_at
        INTO
            capability_current_status,
            capability_deleted_at
        FROM raamaesha.capabilities AS c
        WHERE c.id = NEW.capability_id;

        IF capability_current_status IS DISTINCT FROM 'active'::public.capability_status
           OR capability_deleted_at IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Agent capability binding cannot be active unless capability % is active and not deleted',
                NEW.capability_id;
        END IF;

    END IF;


    RETURN NEW;
END;
$$;


COMMENT ON FUNCTION raamaesha.enforce_agent_capability_binding_lifecycle() IS
'Enforces agent capability binding lifecycle transitions and requires active bindings to reference active, non-deleted capabilities.';


-- =============================================================================
-- Published Agent Version Protection
-- =============================================================================
--
-- Once an agent version is published or retired, its capability composition
-- becomes immutable.
--
-- Only non-structural audit fields may continue to change.
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.prevent_published_agent_capability_binding_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    agent_version_current_status public.agent_version_status;
BEGIN

    SELECT av.status
    INTO agent_version_current_status
    FROM raamaesha.agent_versions AS av
    WHERE av.id = OLD.agent_version_id;

    IF agent_version_current_status IN
       (
           'published'::public.agent_version_status,
           'retired'::public.agent_version_status
       )
    THEN

        IF NEW.agent_version_id IS DISTINCT FROM OLD.agent_version_id
           OR NEW.capability_id IS DISTINCT FROM OLD.capability_id
           OR NEW.status IS DISTINCT FROM OLD.status
           OR NEW.configuration IS DISTINCT FROM OLD.configuration
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
        THEN
            RAISE EXCEPTION
                'Capability binding % cannot be structurally modified because agent version % is %',
                OLD.id,
                OLD.agent_version_id,
                agent_version_current_status;
        END IF;

    END IF;


    RETURN NEW;
END;
$$;


COMMENT ON FUNCTION raamaesha.prevent_published_agent_capability_binding_mutation() IS
'Prevents structural mutation of capability bindings belonging to published or retired agent versions.';


-- =============================================================================
-- Published Agent Version Binding Insert Protection
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.prevent_published_agent_capability_binding_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    agent_version_current_status public.agent_version_status;
BEGIN

    SELECT av.status
    INTO agent_version_current_status
    FROM raamaesha.agent_versions AS av
    WHERE av.id = NEW.agent_version_id;

    IF agent_version_current_status IN
       (
           'published'::public.agent_version_status,
           'retired'::public.agent_version_status
       )
    THEN
        RAISE EXCEPTION
            'Capability binding cannot be added because agent version % is %',
            NEW.agent_version_id,
            agent_version_current_status
            USING ERRCODE = '55000';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION raamaesha.prevent_published_agent_capability_binding_insert() IS
'Prevents adding capability bindings to published or retired agent versions.';

-- =============================================================================
-- Published Agent Version Binding Insert Trigger
-- =============================================================================

CREATE TRIGGER trg_agent_capability_bindings_published_insert
BEFORE INSERT
ON raamaesha.agent_capability_bindings
FOR EACH ROW
EXECUTE FUNCTION raamaesha.prevent_published_agent_capability_binding_insert();

-- =============================================================================
-- Published Agent Version Binding Delete Protection
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.prevent_published_agent_capability_binding_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    agent_version_current_status public.agent_version_status;
BEGIN

    SELECT av.status
    INTO agent_version_current_status
    FROM raamaesha.agent_versions AS av
    WHERE av.id = OLD.agent_version_id;

    IF agent_version_current_status IN
       (
           'published'::public.agent_version_status,
           'retired'::public.agent_version_status
       )
    THEN
        RAISE EXCEPTION
            'Capability binding % cannot be deleted because agent version % is %',
            OLD.id,
            OLD.agent_version_id,
            agent_version_current_status;
    END IF;

    RETURN OLD;
END;
$$;


COMMENT ON FUNCTION raamaesha.prevent_published_agent_capability_binding_delete() IS
'Prevents deletion of capability bindings belonging to published or retired agent versions.';


-- =============================================================================
-- Updated At Trigger
-- =============================================================================

CREATE TRIGGER trg_agent_capability_bindings_set_updated_at
BEFORE UPDATE
ON raamaesha.agent_capability_bindings
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Lifecycle Trigger
-- =============================================================================

CREATE TRIGGER trg_agent_capability_bindings_lifecycle
BEFORE INSERT OR UPDATE
ON raamaesha.agent_capability_bindings
FOR EACH ROW
EXECUTE FUNCTION raamaesha.enforce_agent_capability_binding_lifecycle();


-- =============================================================================
-- Published Agent Version Mutation Protection
-- =============================================================================

CREATE TRIGGER trg_agent_capability_bindings_published_mutation
BEFORE UPDATE
ON raamaesha.agent_capability_bindings
FOR EACH ROW
EXECUTE FUNCTION raamaesha.prevent_published_agent_capability_binding_mutation();


-- =============================================================================
-- Published Agent Version Delete Protection
-- =============================================================================

CREATE TRIGGER trg_agent_capability_bindings_published_delete
BEFORE DELETE
ON raamaesha.agent_capability_bindings
FOR EACH ROW
EXECUTE FUNCTION raamaesha.prevent_published_agent_capability_binding_delete();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;
