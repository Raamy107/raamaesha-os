-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 050_workflow_foundation.sql
-- Module    : Workflow Engine
--
-- Purpose:
--   Creates the foundational durable workflow model for tenant-scoped
--   business process definition, versioning, execution, and retry history.
--
-- Responsibilities:
--   - Workflow definition identity
--   - Workflow version management
--   - Workflow step definition
--   - Workflow runtime instances
--   - Workflow step execution attempts
--   - Version integrity
--   - Tenant integrity
--   - Runtime lifecycle integrity
--   - Historical execution preservation
--
-- Design Boundary:
--   - Event Platform remains responsible for immutable event occurrences.
--   - Rules Engine remains responsible for business rule evaluation.
--   - Capability / Integration Platform remains responsible for operation
--     execution.
--   - Scheduler, workers, retry orchestration, and transition execution
--     remain outside this database foundation.
--
-- Dependencies:
--   - 001_extensions.sql
--   - 003_schema_core.sql
--   - 007_identity_actor.sql
--   - 013_audit_infrastructure.sql
--   - 044_event_platform.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- ENUM : workflow_definition_status
-- =============================================================================
--
-- Defines the lifecycle state of a workflow definition identity.
-- =============================================================================

CREATE TYPE public.workflow_definition_status AS ENUM
(
    'draft',
    'active',
    'archived'
);


COMMENT ON TYPE public.workflow_definition_status IS
'Defines the lifecycle states of a workflow definition within the Workflow Engine.';


-- =============================================================================
-- ENUM : workflow_version_status
-- =============================================================================
--
-- Defines the lifecycle state of a workflow version.
-- =============================================================================

CREATE TYPE public.workflow_version_status AS ENUM
(
    'draft',
    'published',
    'retired'
);


COMMENT ON TYPE public.workflow_version_status IS
'Defines the lifecycle states of a workflow version within the Workflow Engine.';


-- =============================================================================
-- ENUM : workflow_step_type
-- =============================================================================
--
-- Defines the initial supported workflow step categories.
-- =============================================================================

CREATE TYPE public.workflow_step_type AS ENUM
(
    'action',
    'condition',
    'wait',
    'notification'
);


COMMENT ON TYPE public.workflow_step_type IS
'Defines the supported foundational workflow step types.';


-- =============================================================================
-- ENUM : workflow_instance_status
-- =============================================================================
--
-- Defines the lifecycle state of a workflow runtime instance.
-- =============================================================================

CREATE TYPE public.workflow_instance_status AS ENUM
(
    'pending',
    'running',
    'completed',
    'failed',
    'cancelled'
);


COMMENT ON TYPE public.workflow_instance_status IS
'Defines the lifecycle states of a workflow runtime instance.';


-- =============================================================================
-- ENUM : workflow_step_execution_status
-- =============================================================================
--
-- Defines the lifecycle state of an individual workflow step execution
-- attempt.
-- =============================================================================

CREATE TYPE public.workflow_step_execution_status AS ENUM
(
    'pending',
    'running',
    'succeeded',
    'failed',
    'cancelled'
);


COMMENT ON TYPE public.workflow_step_execution_status IS
'Defines the lifecycle states of a workflow step execution attempt.';


-- =============================================================================
-- TABLE : workflow_definitions
-- =============================================================================
--
-- Represents the stable identity of a business workflow within one
-- organization.
--
-- Definition metadata is intentionally separated from executable workflow
-- version structure.
-- =============================================================================

CREATE TABLE raamaesha.workflow_definitions
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id
        UUID
        NOT NULL,

    code
        CITEXT
        NOT NULL,

    name
        TEXT
        NOT NULL,

    description
        TEXT,

    status
        public.workflow_definition_status
        NOT NULL
        DEFAULT 'draft',

    created_by
        UUID,

    updated_by
        UUID,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at
        TIMESTAMPTZ,


    CONSTRAINT pk_workflow_definitions
        PRIMARY KEY (id),


    CONSTRAINT fk_workflow_definitions_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_definitions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_workflow_definitions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT ck_workflow_definitions_code_not_blank
        CHECK (
            length(trim(code::TEXT)) > 0
        ),


    CONSTRAINT ck_workflow_definitions_name_not_blank
        CHECK (
            length(trim(name)) > 0
        ),


    CONSTRAINT uq_workflow_definitions_id_organization
        UNIQUE (id, organization_id)
);


COMMENT ON TABLE raamaesha.workflow_definitions IS
'Stable tenant-scoped identities for business workflows within the RaamaEsha OS Workflow Engine.';


COMMENT ON COLUMN raamaesha.workflow_definitions.id IS
'Globally unique identifier for the workflow definition.';


COMMENT ON COLUMN raamaesha.workflow_definitions.organization_id IS
'Tenant organization that owns the workflow definition.';


COMMENT ON COLUMN raamaesha.workflow_definitions.code IS
'Stable machine-readable workflow code unique within the organization.';


COMMENT ON COLUMN raamaesha.workflow_definitions.name IS
'Human-readable workflow definition name.';


COMMENT ON COLUMN raamaesha.workflow_definitions.description IS
'Optional description of the workflow business purpose.';


COMMENT ON COLUMN raamaesha.workflow_definitions.status IS
'Current lifecycle state of the workflow definition.';


COMMENT ON COLUMN raamaesha.workflow_definitions.created_by IS
'Actor that created the workflow definition.';


COMMENT ON COLUMN raamaesha.workflow_definitions.updated_by IS
'Actor that last updated the workflow definition.';


COMMENT ON COLUMN raamaesha.workflow_definitions.created_at IS
'Timestamp when the workflow definition was created.';


COMMENT ON COLUMN raamaesha.workflow_definitions.updated_at IS
'Timestamp when the workflow definition was last updated.';


COMMENT ON COLUMN raamaesha.workflow_definitions.deleted_at IS
'Soft deletion timestamp. NULL indicates that the workflow definition has not been soft deleted.';


CREATE INDEX idx_workflow_definitions_organization_id
    ON raamaesha.workflow_definitions (organization_id);


CREATE INDEX idx_workflow_definitions_status
    ON raamaesha.workflow_definitions (status);


CREATE INDEX idx_workflow_definitions_deleted_at
    ON raamaesha.workflow_definitions (deleted_at);


CREATE UNIQUE INDEX ux_workflow_definitions_organization_code
    ON raamaesha.workflow_definitions
    (
        organization_id,
        code
    )
    WHERE deleted_at IS NULL;


COMMENT ON INDEX
    raamaesha.ux_workflow_definitions_organization_code IS
'Ensures that each organization has at most one non-deleted workflow definition for a given code.';


-- =============================================================================
-- TABLE : workflow_versions
-- =============================================================================
--
-- Represents a version-controlled executable form of a workflow definition.
-- =============================================================================

CREATE TABLE raamaesha.workflow_versions
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    workflow_definition_id
        UUID
        NOT NULL,

    version_number
        INTEGER
        NOT NULL,

    status
        public.workflow_version_status
        NOT NULL
        DEFAULT 'draft',

    description
        TEXT,

    published_at
        TIMESTAMPTZ,

    created_by
        UUID,

    updated_by
        UUID,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at
        TIMESTAMPTZ,


    CONSTRAINT pk_workflow_versions
        PRIMARY KEY (id),


    CONSTRAINT fk_workflow_versions_definition
        FOREIGN KEY (workflow_definition_id)
        REFERENCES raamaesha.workflow_definitions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_versions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_workflow_versions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT ck_workflow_versions_version_number_positive
        CHECK (
            version_number >= 1
        ),


    CONSTRAINT ck_workflow_versions_published_has_timestamp
        CHECK (
            status <> 'published'
            OR published_at IS NOT NULL
        ),


    CONSTRAINT ck_workflow_versions_draft_has_no_published_timestamp
        CHECK (
            status <> 'draft'
            OR published_at IS NULL
        ),


    CONSTRAINT uq_workflow_versions_definition_version
        UNIQUE (
            workflow_definition_id,
            version_number
        ),


    CONSTRAINT uq_workflow_versions_id_definition
        UNIQUE (
            id,
            workflow_definition_id
        )
);


COMMENT ON TABLE raamaesha.workflow_versions IS
'Version-controlled executable workflow definitions preserved for historical runtime integrity.';


COMMENT ON COLUMN raamaesha.workflow_versions.id IS
'Globally unique identifier for the workflow version.';


COMMENT ON COLUMN raamaesha.workflow_versions.workflow_definition_id IS
'Workflow definition identity to which this version belongs.';


COMMENT ON COLUMN raamaesha.workflow_versions.version_number IS
'Monotonically assigned workflow version number within a workflow definition.';


COMMENT ON COLUMN raamaesha.workflow_versions.status IS
'Current lifecycle state of the workflow version.';


COMMENT ON COLUMN raamaesha.workflow_versions.description IS
'Optional description of the changes or purpose of this workflow version.';


COMMENT ON COLUMN raamaesha.workflow_versions.published_at IS
'Timestamp when the workflow version became published.';


COMMENT ON COLUMN raamaesha.workflow_versions.created_by IS
'Actor that created the workflow version.';


COMMENT ON COLUMN raamaesha.workflow_versions.updated_by IS
'Actor that last updated the workflow version.';


COMMENT ON COLUMN raamaesha.workflow_versions.created_at IS
'Timestamp when the workflow version was created.';


COMMENT ON COLUMN raamaesha.workflow_versions.updated_at IS
'Timestamp when the workflow version was last updated.';


COMMENT ON COLUMN raamaesha.workflow_versions.deleted_at IS
'Soft deletion timestamp. NULL indicates that the workflow version has not been soft deleted.';


CREATE INDEX idx_workflow_versions_definition_id
    ON raamaesha.workflow_versions (workflow_definition_id);


CREATE INDEX idx_workflow_versions_status
    ON raamaesha.workflow_versions (status);


CREATE INDEX idx_workflow_versions_deleted_at
    ON raamaesha.workflow_versions (deleted_at);


CREATE INDEX idx_workflow_versions_definition_version
    ON raamaesha.workflow_versions
    (
        workflow_definition_id,
        version_number
    );


CREATE UNIQUE INDEX ux_workflow_versions_one_published
    ON raamaesha.workflow_versions
    (
        workflow_definition_id
    )
    WHERE status = 'published'
      AND deleted_at IS NULL;


COMMENT ON INDEX
    raamaesha.ux_workflow_versions_one_published IS
'Ensures that each workflow definition has at most one non-deleted published workflow version.';


-- =============================================================================
-- TABLE : workflow_steps
-- =============================================================================
--
-- Represents executable workflow structure belonging to one workflow version.
-- =============================================================================

CREATE TABLE raamaesha.workflow_steps
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    workflow_version_id
        UUID
        NOT NULL,

    code
        CITEXT
        NOT NULL,

    name
        TEXT
        NOT NULL,

    description
        TEXT,

    sequence_no
        INTEGER
        NOT NULL,

    step_type
        public.workflow_step_type
        NOT NULL,

    is_required
        BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    created_by
        UUID,

    updated_by
        UUID,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at
        TIMESTAMPTZ,


    CONSTRAINT pk_workflow_steps
        PRIMARY KEY (id),


    CONSTRAINT fk_workflow_steps_version
        FOREIGN KEY (workflow_version_id)
        REFERENCES raamaesha.workflow_versions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_steps_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_workflow_steps_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT ck_workflow_steps_sequence_positive
        CHECK (
            sequence_no >= 1
        ),


    CONSTRAINT ck_workflow_steps_name_not_blank
        CHECK (
            length(trim(name)) > 0
        ),


    CONSTRAINT ck_workflow_steps_code_not_blank
        CHECK (
            length(trim(code::TEXT)) > 0
        ),


    CONSTRAINT uq_workflow_steps_id_version
        UNIQUE (
            id,
            workflow_version_id
        )
);


COMMENT ON TABLE raamaesha.workflow_steps IS
'Workflow step definitions belonging to a specific workflow version.';


COMMENT ON COLUMN raamaesha.workflow_steps.id IS
'Globally unique identifier for the workflow step.';


COMMENT ON COLUMN raamaesha.workflow_steps.workflow_version_id IS
'Workflow version containing this step definition.';


COMMENT ON COLUMN raamaesha.workflow_steps.code IS
'Stable machine-readable step code unique within the workflow version.';


COMMENT ON COLUMN raamaesha.workflow_steps.name IS
'Human-readable workflow step name.';


COMMENT ON COLUMN raamaesha.workflow_steps.description IS
'Optional description of the workflow step.';


COMMENT ON COLUMN raamaesha.workflow_steps.sequence_no IS
'Positive execution sequence position of the step within the workflow version.';


COMMENT ON COLUMN raamaesha.workflow_steps.step_type IS
'Foundational category defining the type of work represented by the step.';


COMMENT ON COLUMN raamaesha.workflow_steps.is_required IS
'Indicates whether the workflow step is required for normal workflow progression.';


COMMENT ON COLUMN raamaesha.workflow_steps.created_by IS
'Actor that created the workflow step.';


COMMENT ON COLUMN raamaesha.workflow_steps.updated_by IS
'Actor that last updated the workflow step.';


COMMENT ON COLUMN raamaesha.workflow_steps.created_at IS
'Timestamp when the workflow step was created.';


COMMENT ON COLUMN raamaesha.workflow_steps.updated_at IS
'Timestamp when the workflow step was last updated.';


COMMENT ON COLUMN raamaesha.workflow_steps.deleted_at IS
'Soft deletion timestamp. NULL indicates that the workflow step has not been soft deleted.';


CREATE INDEX idx_workflow_steps_version_id
    ON raamaesha.workflow_steps (workflow_version_id);


CREATE INDEX idx_workflow_steps_sequence_no
    ON raamaesha.workflow_steps (sequence_no);


CREATE INDEX idx_workflow_steps_step_type
    ON raamaesha.workflow_steps (step_type);


CREATE INDEX idx_workflow_steps_deleted_at
    ON raamaesha.workflow_steps (deleted_at);


CREATE UNIQUE INDEX ux_workflow_steps_version_sequence
    ON raamaesha.workflow_steps
    (
        workflow_version_id,
        sequence_no
    )
    WHERE deleted_at IS NULL;


CREATE UNIQUE INDEX ux_workflow_steps_version_code
    ON raamaesha.workflow_steps
    (
        workflow_version_id,
        code
    )
    WHERE deleted_at IS NULL;


COMMENT ON INDEX
    raamaesha.ux_workflow_steps_version_sequence IS
'Ensures that each non-deleted workflow step has a unique sequence position within its workflow version.';


COMMENT ON INDEX
    raamaesha.ux_workflow_steps_version_code IS
'Ensures that each non-deleted workflow step has a unique code within its workflow version.';


-- =============================================================================
-- TABLE : workflow_instances
-- =============================================================================
--
-- Represents one durable runtime execution of a workflow version.
-- =============================================================================

CREATE TABLE raamaesha.workflow_instances
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id
        UUID
        NOT NULL,

    workflow_definition_id
        UUID
        NOT NULL,

    workflow_version_id
        UUID
        NOT NULL,

    status
        public.workflow_instance_status
        NOT NULL
        DEFAULT 'pending',

    correlation_id
        TEXT,

    trigger_event_id
        UUID,

    context
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    started_at
        TIMESTAMPTZ,

    completed_at
        TIMESTAMPTZ,

    created_by
        UUID,

    updated_by
        UUID,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at
        TIMESTAMPTZ,


    CONSTRAINT pk_workflow_instances
        PRIMARY KEY (id),


    CONSTRAINT fk_workflow_instances_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_instances_definition_organization
        FOREIGN KEY (
            workflow_definition_id,
            organization_id
        )
        REFERENCES raamaesha.workflow_definitions(
            id,
            organization_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_instances_version_definition
        FOREIGN KEY (
            workflow_version_id,
            workflow_definition_id
        )
        REFERENCES raamaesha.workflow_versions(
            id,
            workflow_definition_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_instances_trigger_event
        FOREIGN KEY (trigger_event_id)
        REFERENCES raamaesha.events(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_instances_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_workflow_instances_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT ck_workflow_instances_context_object
        CHECK (
            jsonb_typeof(context) = 'object'
        ),


    CONSTRAINT ck_workflow_instances_pending_not_started
        CHECK (
            status <> 'pending'
            OR started_at IS NULL
        ),


    CONSTRAINT ck_workflow_instances_pending_not_completed
        CHECK (
            status <> 'pending'
            OR completed_at IS NULL
        ),


    CONSTRAINT ck_workflow_instances_running_started
        CHECK (
            status <> 'running'
            OR started_at IS NOT NULL
        ),


    CONSTRAINT ck_workflow_instances_running_not_completed
        CHECK (
            status <> 'running'
            OR completed_at IS NULL
        ),


    CONSTRAINT ck_workflow_instances_terminal_started
        CHECK (
            status NOT IN ('completed', 'failed', 'cancelled')
            OR started_at IS NOT NULL
        ),


    CONSTRAINT ck_workflow_instances_terminal_completed
        CHECK (
            status NOT IN ('completed', 'failed', 'cancelled')
            OR completed_at IS NOT NULL
        ),


    CONSTRAINT uq_workflow_instances_id_version
        UNIQUE (
            id,
            workflow_version_id
        )
);


COMMENT ON TABLE raamaesha.workflow_instances IS
'Durable tenant-scoped runtime instances preserving the exact workflow version used for execution.';


COMMENT ON COLUMN raamaesha.workflow_instances.id IS
'Globally unique identifier for the workflow runtime instance.';


COMMENT ON COLUMN raamaesha.workflow_instances.organization_id IS
'Tenant organization in whose business context the workflow instance executes.';


COMMENT ON COLUMN raamaesha.workflow_instances.workflow_definition_id IS
'Workflow definition identity associated with this runtime instance.';


COMMENT ON COLUMN raamaesha.workflow_instances.workflow_version_id IS
'Exact workflow version used by this runtime instance and preserved for historical integrity.';


COMMENT ON COLUMN raamaesha.workflow_instances.status IS
'Current lifecycle state of the workflow runtime instance.';


COMMENT ON COLUMN raamaesha.workflow_instances.correlation_id IS
'Optional correlation identifier used to associate the workflow instance with related operations and business activity.';


COMMENT ON COLUMN raamaesha.workflow_instances.trigger_event_id IS
'Optional immutable Event Platform event that initiated the workflow instance.';


COMMENT ON COLUMN raamaesha.workflow_instances.context IS
'Durable structured runtime context for the workflow instance.';


COMMENT ON COLUMN raamaesha.workflow_instances.started_at IS
'Timestamp when workflow runtime execution started.';


COMMENT ON COLUMN raamaesha.workflow_instances.completed_at IS
'Timestamp when workflow runtime execution reached a terminal state.';


COMMENT ON COLUMN raamaesha.workflow_instances.created_by IS
'Actor that created the workflow runtime instance.';


COMMENT ON COLUMN raamaesha.workflow_instances.updated_by IS
'Actor that last updated the workflow runtime instance.';


COMMENT ON COLUMN raamaesha.workflow_instances.created_at IS
'Timestamp when the workflow runtime instance was created.';


COMMENT ON COLUMN raamaesha.workflow_instances.updated_at IS
'Timestamp when the workflow runtime instance was last updated.';


COMMENT ON COLUMN raamaesha.workflow_instances.deleted_at IS
'Soft deletion timestamp. NULL indicates that the workflow instance has not been soft deleted.';


CREATE INDEX idx_workflow_instances_organization_id
    ON raamaesha.workflow_instances (organization_id);


CREATE INDEX idx_workflow_instances_definition_id
    ON raamaesha.workflow_instances (workflow_definition_id);


CREATE INDEX idx_workflow_instances_version_id
    ON raamaesha.workflow_instances (workflow_version_id);


CREATE INDEX idx_workflow_instances_status
    ON raamaesha.workflow_instances (status);


CREATE INDEX idx_workflow_instances_correlation_id
    ON raamaesha.workflow_instances (correlation_id)
    WHERE correlation_id IS NOT NULL;


CREATE INDEX idx_workflow_instances_trigger_event_id
    ON raamaesha.workflow_instances (trigger_event_id)
    WHERE trigger_event_id IS NOT NULL;


CREATE INDEX idx_workflow_instances_created_at
    ON raamaesha.workflow_instances (created_at DESC);


CREATE INDEX idx_workflow_instances_deleted_at
    ON raamaesha.workflow_instances (deleted_at);


-- =============================================================================
-- TABLE : workflow_step_executions
-- =============================================================================
--
-- Represents one durable execution attempt for one workflow step.
--
-- workflow_version_id is intentionally stored here so PostgreSQL can enforce
-- that the instance and step belong to the same workflow version.
-- =============================================================================

CREATE TABLE raamaesha.workflow_step_executions
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    workflow_instance_id
        UUID
        NOT NULL,

    workflow_version_id
        UUID
        NOT NULL,

    workflow_step_id
        UUID
        NOT NULL,

    attempt_number
        INTEGER
        NOT NULL,

    status
        public.workflow_step_execution_status
        NOT NULL
        DEFAULT 'pending',

    started_at
        TIMESTAMPTZ,

    completed_at
        TIMESTAMPTZ,

    error_code
        TEXT,

    error_message
        TEXT,

    result
        JSONB,

    created_by
        UUID,

    updated_by
        UUID,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at
        TIMESTAMPTZ,


    CONSTRAINT pk_workflow_step_executions
        PRIMARY KEY (id),


    CONSTRAINT fk_workflow_step_executions_instance_version
        FOREIGN KEY (
            workflow_instance_id,
            workflow_version_id
        )
        REFERENCES raamaesha.workflow_instances(
            id,
            workflow_version_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_step_executions_step_version
        FOREIGN KEY (
            workflow_step_id,
            workflow_version_id
        )
        REFERENCES raamaesha.workflow_steps(
            id,
            workflow_version_id
        )
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    CONSTRAINT fk_workflow_step_executions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_workflow_step_executions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT ck_workflow_step_executions_attempt_positive
        CHECK (
            attempt_number >= 1
        ),


    CONSTRAINT ck_workflow_step_executions_pending_not_started
        CHECK (
            status <> 'pending'
            OR started_at IS NULL
        ),


    CONSTRAINT ck_workflow_step_executions_pending_not_completed
        CHECK (
            status <> 'pending'
            OR completed_at IS NULL
        ),


    CONSTRAINT ck_workflow_step_executions_running_started
        CHECK (
            status <> 'running'
            OR started_at IS NOT NULL
        ),


    CONSTRAINT ck_workflow_step_executions_running_not_completed
        CHECK (
            status <> 'running'
            OR completed_at IS NULL
        ),


    CONSTRAINT ck_workflow_step_executions_terminal_started
        CHECK (
            status NOT IN ('succeeded', 'failed', 'cancelled')
            OR started_at IS NOT NULL
        ),


    CONSTRAINT ck_workflow_step_executions_terminal_completed
        CHECK (
            status NOT IN ('succeeded', 'failed', 'cancelled')
            OR completed_at IS NOT NULL
        ),


    CONSTRAINT uq_workflow_step_executions_attempt
        UNIQUE (
            workflow_instance_id,
            workflow_step_id,
            attempt_number
        )
);


COMMENT ON TABLE raamaesha.workflow_step_executions IS
'Durable execution attempts for workflow steps, including retry history.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.id IS
'Globally unique identifier for the workflow step execution attempt.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.workflow_instance_id IS
'Workflow runtime instance containing the step execution.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.workflow_version_id IS
'Workflow version shared by the runtime instance and executed workflow step, enforcing cross-version integrity.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.workflow_step_id IS
'Workflow step definition being executed.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.attempt_number IS
'One-based execution attempt number for the workflow step within the workflow instance.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.status IS
'Current lifecycle state of the workflow step execution attempt.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.started_at IS
'Timestamp when this step execution attempt started.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.completed_at IS
'Timestamp when this step execution attempt reached a terminal state.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.error_code IS
'Optional machine-readable error code associated with a failed execution attempt.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.error_message IS
'Optional human-readable error information associated with a failed execution attempt.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.result IS
'Optional structured result produced by the workflow step execution attempt.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.created_by IS
'Actor or execution identity that created the step execution record.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.updated_by IS
'Actor or execution identity that last updated the step execution record.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.created_at IS
'Timestamp when the step execution attempt was created.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.updated_at IS
'Timestamp when the step execution attempt was last updated.';


COMMENT ON COLUMN raamaesha.workflow_step_executions.deleted_at IS
'Soft deletion timestamp. NULL indicates that the step execution record has not been soft deleted.';


CREATE INDEX idx_workflow_step_executions_instance_id
    ON raamaesha.workflow_step_executions (workflow_instance_id);


CREATE INDEX idx_workflow_step_executions_version_id
    ON raamaesha.workflow_step_executions (workflow_version_id);


CREATE INDEX idx_workflow_step_executions_step_id
    ON raamaesha.workflow_step_executions (workflow_step_id);


CREATE INDEX idx_workflow_step_executions_status
    ON raamaesha.workflow_step_executions (status);


CREATE INDEX idx_workflow_step_executions_created_at
    ON raamaesha.workflow_step_executions (created_at DESC);


CREATE INDEX idx_workflow_step_executions_pending
    ON raamaesha.workflow_step_executions (created_at)
    WHERE status = 'pending'
      AND deleted_at IS NULL;


CREATE INDEX idx_workflow_step_executions_deleted_at
    ON raamaesha.workflow_step_executions (deleted_at);


COMMENT ON INDEX
    raamaesha.idx_workflow_step_executions_pending IS
'Supports efficient discovery of non-deleted pending workflow step execution attempts.';


-- =============================================================================
-- Workflow Version Immutability
-- =============================================================================
--
-- Published and retired workflow versions are structurally immutable.
-- Lifecycle status itself may transition from published to retired.
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.prevent_published_workflow_version_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN

    IF OLD.status IN ('published', 'retired') THEN

        IF OLD.status = 'published'
           AND NEW.status NOT IN ('published', 'retired')
        THEN
            RAISE EXCEPTION
                'Published workflow versions may only remain published or transition to retired'
                USING ERRCODE = '55000';
        END IF;


        IF OLD.status = 'retired'
           AND NEW.status <> 'retired'
        THEN
            RAISE EXCEPTION
                'Retired workflow versions cannot change lifecycle status'
                USING ERRCODE = '55000';
        END IF;


        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION
                'Published or retired workflow versions cannot be deleted'
                USING ERRCODE = '55000';
        END IF;


        IF NEW.workflow_definition_id IS DISTINCT FROM OLD.workflow_definition_id
           OR NEW.version_number IS DISTINCT FROM OLD.version_number
           OR NEW.description IS DISTINCT FROM OLD.description
           OR NEW.published_at IS DISTINCT FROM OLD.published_at
           OR NEW.created_by IS DISTINCT FROM OLD.created_by
           OR NEW.created_at IS DISTINCT FROM OLD.created_at
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
        THEN
            RAISE EXCEPTION
                'Published or retired workflow versions are structurally immutable'
                USING ERRCODE = '55000';
        END IF;

    END IF;


    RETURN NEW;

END;
$$;


COMMENT ON FUNCTION raamaesha.prevent_published_workflow_version_mutation()
IS
'Prevents structural mutation or deletion of published and retired workflow versions while allowing lifecycle retirement.';


CREATE TRIGGER trg_workflow_versions_immutable
BEFORE UPDATE OR DELETE
ON raamaesha.workflow_versions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.prevent_published_workflow_version_mutation();


-- =============================================================================
-- Workflow Step Immutability
-- =============================================================================
--
-- Steps belonging to published or retired versions are structurally immutable.
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.prevent_published_workflow_step_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
DECLARE
    v_version_status public.workflow_version_status;
BEGIN

    SELECT status
    INTO v_version_status
    FROM raamaesha.workflow_versions
    WHERE id = OLD.workflow_version_id
    FOR UPDATE;


    IF v_version_status IN ('published', 'retired') THEN

        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION
                'Workflow steps belonging to published or retired versions cannot be deleted'
                USING ERRCODE = '55000';
        END IF;


        IF NEW.workflow_version_id IS DISTINCT FROM OLD.workflow_version_id
           OR NEW.code IS DISTINCT FROM OLD.code
           OR NEW.name IS DISTINCT FROM OLD.name
           OR NEW.description IS DISTINCT FROM OLD.description
           OR NEW.sequence_no IS DISTINCT FROM OLD.sequence_no
           OR NEW.step_type IS DISTINCT FROM OLD.step_type
           OR NEW.is_required IS DISTINCT FROM OLD.is_required
           OR NEW.created_by IS DISTINCT FROM OLD.created_by
           OR NEW.created_at IS DISTINCT FROM OLD.created_at
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
        THEN
            RAISE EXCEPTION
                'Workflow steps belonging to published or retired versions are structurally immutable'
                USING ERRCODE = '55000';
        END IF;

    END IF;


    RETURN NEW;

END;
$$;


COMMENT ON FUNCTION raamaesha.prevent_published_workflow_step_mutation()
IS
'Prevents structural mutation or deletion of workflow steps belonging to published or retired workflow versions.';


CREATE TRIGGER trg_workflow_steps_immutable
BEFORE UPDATE OR DELETE
ON raamaesha.workflow_steps
FOR EACH ROW
EXECUTE FUNCTION raamaesha.prevent_published_workflow_step_mutation();


-- =============================================================================
-- Updated At Triggers
-- =============================================================================
--
-- Reuses the shared audit infrastructure established by Migration 013.
-- =============================================================================

CREATE TRIGGER trg_workflow_definitions_set_updated_at
BEFORE UPDATE
ON raamaesha.workflow_definitions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


CREATE TRIGGER trg_workflow_versions_set_updated_at
BEFORE UPDATE
ON raamaesha.workflow_versions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


CREATE TRIGGER trg_workflow_steps_set_updated_at
BEFORE UPDATE
ON raamaesha.workflow_steps
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


CREATE TRIGGER trg_workflow_instances_set_updated_at
BEFORE UPDATE
ON raamaesha.workflow_instances
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


CREATE TRIGGER trg_workflow_step_executions_set_updated_at
BEFORE UPDATE
ON raamaesha.workflow_step_executions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Constraint Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    ck_workflow_versions_version_number_positive
ON raamaesha.workflow_versions IS
'Ensures that workflow version numbers begin at one and remain positive.';


COMMENT ON CONSTRAINT
    ck_workflow_versions_published_has_timestamp
ON raamaesha.workflow_versions IS
'Ensures that every published workflow version has a publication timestamp.';


COMMENT ON CONSTRAINT
    ck_workflow_versions_draft_has_no_published_timestamp
ON raamaesha.workflow_versions IS
'Ensures that draft workflow versions do not carry a publication timestamp.';


COMMENT ON CONSTRAINT
    ck_workflow_instances_context_object
ON raamaesha.workflow_instances IS
'Ensures that workflow runtime context is stored as a JSON object.';


COMMENT ON CONSTRAINT
    ck_workflow_step_executions_attempt_positive
ON raamaesha.workflow_step_executions IS
'Ensures that workflow step execution attempts are numbered from one upward.';


COMMENT ON CONSTRAINT
    uq_workflow_step_executions_attempt
ON raamaesha.workflow_step_executions IS
'Ensures that each workflow step execution attempt identity is unique within a workflow instance.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;


-- =============================================================================
-- End Migration 050
-- =============================================================================
