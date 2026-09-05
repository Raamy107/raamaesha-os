-- ============================================================
-- RaamaEsha OS Founder Edition v1.0
-- Migration 051: Agent Foundation
-- ============================================================
--
-- Purpose:
-- Establish the durable tenant-scoped foundation for AI agents.
--
-- Scope:
--   1. Agent definitions
--   2. Agent versions
--   3. Agent instances
--   4. Agent lifecycle integrity
--   5. Published-version immutability
--   6. Tenant and audit integrity
--
-- Explicitly NOT included:
--   - Agent capability/tool bindings
--   - Agent permissions/governance
--   - Agent runs/execution
--   - Agent factory/builder
--   - Agent memory
--   - Agent-to-agent orchestration
--   - Application/trend intelligence
--
-- Architectural rule:
-- Agents must operate through the RaamaEsha OS control plane.
-- They must never bypass permissions, capabilities, operations,
-- integrations, workflows, events, or audit infrastructure.
-- ============================================================


-- ============================================================
-- 1. ENUM TYPES
-- ============================================================

-- Agent definition lifecycle.
CREATE TYPE public.agent_definition_status AS ENUM (
    'draft',
    'active',
    'archived'
);


-- Agent version lifecycle.
CREATE TYPE public.agent_version_status AS ENUM (
    'draft',
    'published',
    'retired'
);


-- Agent instance lifecycle.
CREATE TYPE public.agent_instance_status AS ENUM (
    'pending',
    'active',
    'paused',
    'stopped',
    'failed'
);


-- ============================================================
-- 2. AGENT DEFINITIONS
-- ============================================================

CREATE TABLE raamaesha.agent_definitions
(
    id UUID NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    code CITEXT NOT NULL,

    name TEXT NOT NULL,

    description TEXT,

    status public.agent_definition_status NOT NULL
        DEFAULT 'draft',

    created_by UUID,

    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_agent_definitions
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_definitions_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_definitions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_definitions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT uq_agent_definitions_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT ck_agent_definitions_code_not_blank
        CHECK (btrim(code::TEXT) <> ''),

    CONSTRAINT ck_agent_definitions_name_not_blank
        CHECK (btrim(name) <> '')
);


-- ============================================================
-- 3. AGENT DEFINITION INDEXES
-- ============================================================

CREATE INDEX idx_agent_definitions_organization_id
    ON raamaesha.agent_definitions (organization_id);

CREATE INDEX idx_agent_definitions_organization_status
    ON raamaesha.agent_definitions (
        organization_id,
        status
    );

CREATE INDEX idx_agent_definitions_deleted_at
    ON raamaesha.agent_definitions (deleted_at);


CREATE UNIQUE INDEX ux_agent_definitions_organization_code
    ON raamaesha.agent_definitions (
        organization_id,
        code
    )
    WHERE deleted_at IS NULL;


-- ============================================================
-- 4. AGENT VERSIONS
-- ============================================================

CREATE TABLE raamaesha.agent_versions
(
    id UUID NOT NULL
        DEFAULT gen_random_uuid(),

    agent_definition_id UUID NOT NULL,

    version_number INTEGER NOT NULL,

    status public.agent_version_status NOT NULL
        DEFAULT 'draft',

    description TEXT,

    configuration JSONB NOT NULL
        DEFAULT '{}'::JSONB,

    published_at TIMESTAMPTZ,

    created_by UUID,

    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_agent_versions
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_versions_agent_definition
        FOREIGN KEY (agent_definition_id)
        REFERENCES raamaesha.agent_definitions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_versions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_versions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT uq_agent_versions_definition_version
        UNIQUE (
            agent_definition_id,
            version_number
        ),

    CONSTRAINT uq_agent_versions_id_definition
        UNIQUE (
            id,
            agent_definition_id
        ),

    CONSTRAINT ck_agent_versions_version_number_positive
        CHECK (version_number >= 1),

    CONSTRAINT ck_agent_versions_configuration_object
        CHECK (
            jsonb_typeof(configuration) = 'object'
        ),

    CONSTRAINT ck_agent_versions_published_requires_timestamp
        CHECK (
            status <> 'published'
            OR published_at IS NOT NULL
        ),

    CONSTRAINT ck_agent_versions_draft_requires_no_timestamp
        CHECK (
            status <> 'draft'
            OR published_at IS NULL
        )
);


-- ============================================================
-- 5. AGENT VERSION INDEXES
-- ============================================================

CREATE INDEX idx_agent_versions_definition_id
    ON raamaesha.agent_versions (
        agent_definition_id
    );

CREATE INDEX idx_agent_versions_definition_version
    ON raamaesha.agent_versions (
        agent_definition_id,
        version_number
    );

CREATE INDEX idx_agent_versions_definition_status
    ON raamaesha.agent_versions (
        agent_definition_id,
        status
    );

CREATE INDEX idx_agent_versions_deleted_at
    ON raamaesha.agent_versions (deleted_at);


CREATE UNIQUE INDEX ux_agent_versions_one_published
    ON raamaesha.agent_versions (
        agent_definition_id
    )
    WHERE status = 'published'
      AND deleted_at IS NULL;


-- ============================================================
-- 6. AGENT INSTANCES
-- ============================================================

CREATE TABLE raamaesha.agent_instances
(
    id UUID NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    agent_definition_id UUID NOT NULL,

    agent_version_id UUID NOT NULL,

    status public.agent_instance_status NOT NULL
        DEFAULT 'pending',

    name TEXT,

    context JSONB NOT NULL
        DEFAULT '{}'::JSONB,

    started_at TIMESTAMPTZ,

    stopped_at TIMESTAMPTZ,

    created_by UUID,

    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_agent_instances
        PRIMARY KEY (id),

    CONSTRAINT fk_agent_instances_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_instances_definition_organization
        FOREIGN KEY (
            agent_definition_id,
            organization_id
        )
        REFERENCES raamaesha.agent_definitions (
            id,
            organization_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_instances_version_definition
        FOREIGN KEY (
            agent_version_id,
            agent_definition_id
        )
        REFERENCES raamaesha.agent_versions (
            id,
            agent_definition_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_agent_instances_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_agent_instances_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT uq_agent_instances_id_version
        UNIQUE (
            id,
            agent_version_id
        ),

    CONSTRAINT ck_agent_instances_context_object
        CHECK (
            jsonb_typeof(context) = 'object'
        ),

    CONSTRAINT ck_agent_instances_name_not_blank
        CHECK (
            name IS NULL
            OR btrim(name) <> ''
        ),

    CONSTRAINT ck_agent_instances_state_timestamps
        CHECK (
            (
                status = 'pending'
                AND started_at IS NULL
                AND stopped_at IS NULL
            )
            OR
            (
                status IN ('active', 'paused')
                AND started_at IS NOT NULL
                AND stopped_at IS NULL
            )
            OR
            (
                status IN ('stopped', 'failed')
                AND started_at IS NOT NULL
                AND stopped_at IS NOT NULL
            )
        )
);


-- ============================================================
-- 7. AGENT INSTANCE INDEXES
-- ============================================================

CREATE INDEX idx_agent_instances_organization_id
    ON raamaesha.agent_instances (
        organization_id
    );

CREATE INDEX idx_agent_instances_definition_id
    ON raamaesha.agent_instances (
        agent_definition_id
    );

CREATE INDEX idx_agent_instances_version_id
    ON raamaesha.agent_instances (
        agent_version_id
    );

CREATE INDEX idx_agent_instances_status
    ON raamaesha.agent_instances (
        status
    );

CREATE INDEX idx_agent_instances_created_at
    ON raamaesha.agent_instances (
        created_at
    );

CREATE INDEX idx_agent_instances_deleted_at
    ON raamaesha.agent_instances (
        deleted_at
    );


-- ============================================================
-- 8. AGENT DEFINITION LIFECYCLE INTEGRITY
-- ============================================================

CREATE OR REPLACE FUNCTION
raamaesha.enforce_agent_definition_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF OLD.status = 'archived' THEN

        IF NEW.status <> 'archived' THEN
            RAISE EXCEPTION
                'Archived agent definitions cannot change lifecycle status'
                USING ERRCODE = '55000';
        END IF;

    ELSIF OLD.status = 'active' THEN

        IF NEW.status NOT IN ('active', 'archived') THEN
            RAISE EXCEPTION
                'Active agent definitions may only remain active or transition to archived'
                USING ERRCODE = '55000';
        END IF;

    END IF;

    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_agent_definitions_lifecycle
    BEFORE UPDATE
    ON raamaesha.agent_definitions
    FOR EACH ROW
    EXECUTE FUNCTION
        raamaesha.enforce_agent_definition_lifecycle();


-- ============================================================
-- 9. AGENT VERSION LIFECYCLE / IMMUTABILITY
-- ============================================================

CREATE OR REPLACE FUNCTION
raamaesha.prevent_published_agent_version_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF OLD.status IN ('published', 'retired') THEN

        IF OLD.status = 'published'
           AND NEW.status NOT IN ('published', 'retired')
        THEN
            RAISE EXCEPTION
                'Published agent versions may only remain published or transition to retired'
                USING ERRCODE = '55000';
        END IF;


        IF OLD.status = 'retired'
           AND NEW.status <> 'retired'
        THEN
            RAISE EXCEPTION
                'Retired agent versions cannot change lifecycle status'
                USING ERRCODE = '55000';
        END IF;


        IF OLD.status IN ('published', 'retired')
           AND (
                OLD.agent_definition_id IS DISTINCT FROM
                    NEW.agent_definition_id
                OR OLD.version_number IS DISTINCT FROM
                    NEW.version_number
                OR OLD.description IS DISTINCT FROM
                    NEW.description
                OR OLD.configuration IS DISTINCT FROM
                    NEW.configuration
                OR OLD.published_at IS DISTINCT FROM
                    NEW.published_at
                OR OLD.created_by IS DISTINCT FROM
                    NEW.created_by
                OR OLD.created_at IS DISTINCT FROM
                    NEW.created_at
                OR OLD.deleted_at IS DISTINCT FROM
                    NEW.deleted_at
           )
        THEN
            RAISE EXCEPTION
                'Published or retired agent versions are structurally immutable'
                USING ERRCODE = '55000';
        END IF;

    END IF;

    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_agent_versions_published_mutation
    BEFORE UPDATE
    ON raamaesha.agent_versions
    FOR EACH ROW
    EXECUTE FUNCTION
        raamaesha.prevent_published_agent_version_mutation();


-- ============================================================
-- 10. AGENT VERSION DELETE PROTECTION
-- ============================================================

CREATE OR REPLACE FUNCTION
raamaesha.prevent_published_agent_version_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF OLD.status IN ('published', 'retired') THEN
        RAISE EXCEPTION
            'Published or retired agent versions cannot be deleted'
            USING ERRCODE = '55000';
    END IF;

    RETURN OLD;

END;
$$;


CREATE TRIGGER trg_agent_versions_published_delete
    BEFORE DELETE
    ON raamaesha.agent_versions
    FOR EACH ROW
    EXECUTE FUNCTION
        raamaesha.prevent_published_agent_version_delete();


-- ============================================================
-- 11. AGENT INSTANCE LIFECYCLE INTEGRITY
-- ============================================================

CREATE OR REPLACE FUNCTION
raamaesha.enforce_agent_instance_lifecycle()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

    IF OLD.status = 'stopped' THEN

        IF NEW.status <> 'stopped' THEN
            RAISE EXCEPTION
                'Stopped agent instances cannot change lifecycle status'
                USING ERRCODE = '55000';
        END IF;

    ELSIF OLD.status = 'failed' THEN

        IF NEW.status <> 'failed' THEN
            RAISE EXCEPTION
                'Failed agent instances cannot change lifecycle status'
                USING ERRCODE = '55000';
        END IF;

    ELSIF OLD.status = 'pending' THEN

        IF NEW.status NOT IN ('pending', 'active', 'failed') THEN
            RAISE EXCEPTION
                'Pending agent instances may transition only to active or failed'
                USING ERRCODE = '55000';
        END IF;

    ELSIF OLD.status = 'active' THEN

        IF NEW.status NOT IN (
            'active',
            'paused',
            'stopped',
            'failed'
        ) THEN
            RAISE EXCEPTION
                'Active agent instances may transition only to active, paused, stopped, or failed'
                USING ERRCODE = '55000';
        END IF;

    ELSIF OLD.status = 'paused' THEN

        IF NEW.status NOT IN (
            'paused',
            'active',
            'stopped',
            'failed'
        ) THEN
            RAISE EXCEPTION
                'Paused agent instances may transition only to paused, active, stopped, or failed'
                USING ERRCODE = '55000';
        END IF;

    END IF;

    RETURN NEW;

END;
$$;


CREATE TRIGGER trg_agent_instances_lifecycle
    BEFORE UPDATE
    ON raamaesha.agent_instances
    FOR EACH ROW
    EXECUTE FUNCTION
        raamaesha.enforce_agent_instance_lifecycle();


-- ============================================================
-- 12. AGENT DEFINITION UPDATED_AT
-- ============================================================

CREATE OR REPLACE FUNCTION
raamaesha.set_agent_definition_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_agent_definitions_updated_at
    BEFORE UPDATE
    ON raamaesha.agent_definitions
    FOR EACH ROW
    EXECUTE FUNCTION
        raamaesha.set_agent_definition_updated_at();


-- ============================================================
-- 13. AGENT VERSION UPDATED_AT
-- ============================================================

CREATE OR REPLACE FUNCTION
raamaesha.set_agent_version_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_agent_versions_updated_at
    BEFORE UPDATE
    ON raamaesha.agent_versions
    FOR EACH ROW
    EXECUTE FUNCTION
        raamaesha.set_agent_version_updated_at();


-- ============================================================
-- 14. AGENT INSTANCE UPDATED_AT
-- ============================================================

CREATE OR REPLACE FUNCTION
raamaesha.set_agent_instance_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


CREATE TRIGGER trg_agent_instances_updated_at
    BEFORE UPDATE
    ON raamaesha.agent_instances
    FOR EACH ROW
    EXECUTE FUNCTION
        raamaesha.set_agent_instance_updated_at();


-- ============================================================
-- 15. COMMENTS
-- ============================================================

COMMENT ON TABLE raamaesha.agent_definitions IS
'Tenant-scoped logical AI agent definitions.';


COMMENT ON TABLE raamaesha.agent_versions IS
'Versioned and lifecycle-controlled configurations of AI agents.';


COMMENT ON TABLE raamaesha.agent_instances IS
'Runtime-scoped instances of configured AI agents.';


COMMENT ON COLUMN raamaesha.agent_versions.configuration IS
'Structured agent configuration stored as a JSON object.';


COMMENT ON COLUMN raamaesha.agent_instances.context IS
'Runtime agent context stored as a JSON object; durable agent memory is implemented separately.';


-- ============================================================
-- END OF MIGRATION 051
-- ============================================================