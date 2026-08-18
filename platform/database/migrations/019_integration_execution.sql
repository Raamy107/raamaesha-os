-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 019_integration_execution.sql
-- Module    : Integration Execution & Operations
--
-- Purpose:
--   Creates the persistent operational execution foundation for the
--   RaamaEsha OS Integration Platform.
--
-- Responsibilities:
--   - Integration execution records
--   - Execution lifecycle management
--   - Operation identification
--   - Idempotency support
--   - Correlation and observability
--   - Retry state tracking
--   - Safe request/response operational metadata
--   - Non-secret execution diagnostics
--
-- Architecture:
--
--   Integration Provider
--          |
--          v
--   Organization Integration
--          |
--          v
--   Integration Connection
--          |
--          v
--   Integration Execution
--
-- Design Principles:
--   - Provider agnostic
--   - Multi-tenant through integration ownership
--   - Connection relationship is tenant-safe
--   - One persistent record represents one logical execution
--   - Retry state is recorded, not executed by the database
--   - Idempotency supported
--   - Correlation supported
--   - No plaintext secrets
--   - No provider-specific business logic
--   - Operational history is retained
--   - Extensible JSONB metadata
--
-- Dependencies:
--   - 001_extensions.sql
--   - 003_schema_core.sql
--   - 007_identity_actor.sql
--   - 013_audit_infrastructure.sql
--   - 018_integration_platform.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- ENUM : Integration Execution Status
-- =============================================================================

CREATE TYPE public.integration_execution_status AS ENUM
(
    'pending',
    'running',
    'succeeded',
    'failed',
    'cancelled',
    'timed_out'
);

COMMENT ON TYPE public.integration_execution_status IS
'Lifecycle state of a logical integration execution.';


-- =============================================================================
-- Integration Executions
-- =============================================================================
--
-- Represents one logical execution of an operation against an existing
-- organization integration.
--
-- Retry state is maintained on the execution record. The actual scheduling,
-- worker execution, retry policy, and provider-specific behavior belong to
-- the application/runtime layer.
--
-- Request and response payloads are intentionally NOT stored here.
-- Only safe operational metadata may be persisted.
-- =============================================================================

CREATE TABLE raamaesha.integration_executions
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    integration_id
        UUID
        NOT NULL,

    connection_id
        UUID,

    operation_code
        TEXT
        NOT NULL,

    status
        public.integration_execution_status
        NOT NULL
        DEFAULT 'pending',

    idempotency_key
        TEXT,

    correlation_id
        TEXT,

    retry_count
        INTEGER
        NOT NULL
        DEFAULT 0,

    next_retry_at
        TIMESTAMPTZ,

    started_at
        TIMESTAMPTZ,

    completed_at
        TIMESTAMPTZ,

    duration_ms
        BIGINT,

    provider_request_id
        TEXT,

    provider_response_id
        TEXT,

    http_status_code
        INTEGER,

    request_metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    response_metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    error_code
        TEXT,

    error_category
        TEXT,

    error_message
        TEXT,

    metadata
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


    CONSTRAINT pk_integration_executions
        PRIMARY KEY (id),

    CONSTRAINT fk_integration_executions_integration
        FOREIGN KEY (integration_id)
        REFERENCES raamaesha.integrations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_integration_executions_connection
        FOREIGN KEY (connection_id, integration_id)
        REFERENCES raamaesha.integration_connections (id, integration_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_integration_executions_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT fk_integration_executions_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT ck_integration_executions_operation_code_not_blank
        CHECK (length(trim(operation_code)) > 0),

    CONSTRAINT ck_integration_executions_idempotency_key_not_blank
        CHECK (
            idempotency_key IS NULL
            OR length(trim(idempotency_key)) > 0
        ),

    CONSTRAINT ck_integration_executions_correlation_id_not_blank
        CHECK (
            correlation_id IS NULL
            OR length(trim(correlation_id)) > 0
        ),

    CONSTRAINT ck_integration_executions_retry_count_non_negative
        CHECK (retry_count >= 0),

    CONSTRAINT ck_integration_executions_duration_ms_non_negative
        CHECK (
            duration_ms IS NULL
            OR duration_ms >= 0
        ),

    CONSTRAINT ck_integration_executions_http_status_code_valid
        CHECK (
            http_status_code IS NULL
            OR http_status_code BETWEEN 100 AND 599
        ),

    CONSTRAINT ck_integration_executions_request_metadata_object
        CHECK (
            jsonb_typeof(request_metadata) = 'object'
        ),

    CONSTRAINT ck_integration_executions_response_metadata_object
        CHECK (
            jsonb_typeof(response_metadata) = 'object'
        ),

    CONSTRAINT ck_integration_executions_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        ),

    CONSTRAINT ck_integration_executions_error_code_not_blank
        CHECK (
            error_code IS NULL
            OR length(trim(error_code)) > 0
        ),

    CONSTRAINT ck_integration_executions_error_category_not_blank
        CHECK (
            error_category IS NULL
            OR length(trim(error_category)) > 0
        ),

    CONSTRAINT ck_integration_executions_error_message_not_blank
        CHECK (
            error_message IS NULL
            OR length(trim(error_message)) > 0
        ),

    CONSTRAINT ck_integration_executions_started_before_completed
        CHECK (
            started_at IS NULL
            OR completed_at IS NULL
            OR completed_at >= started_at
        ),

    CONSTRAINT ck_integration_executions_terminal_completed
        CHECK (
            status IN ('pending', 'running')
            OR completed_at IS NOT NULL
        ),

    CONSTRAINT ck_integration_executions_running_started
        CHECK (
            status <> 'running'
            OR started_at IS NOT NULL
        ),

    CONSTRAINT ck_integration_executions_retry_schedule_state
        CHECK (
            next_retry_at IS NULL
            OR status IN ('pending', 'failed')
        )
);


-- =============================================================================
-- Integration Execution Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.integration_executions IS
'Persistent operational records representing logical integration executions.';

COMMENT ON COLUMN raamaesha.integration_executions.id IS
'Globally unique identifier for the integration execution.';

COMMENT ON COLUMN raamaesha.integration_executions.integration_id IS
'Organization-owned integration against which the execution occurs.';

COMMENT ON COLUMN raamaesha.integration_executions.connection_id IS
'Optional physical integration connection used for the execution. The composite foreign key ensures the connection belongs to the same integration.';

COMMENT ON COLUMN raamaesha.integration_executions.operation_code IS
'Provider-independent identifier describing the operation being executed.';

COMMENT ON COLUMN raamaesha.integration_executions.status IS
'Current lifecycle state of the integration execution.';

COMMENT ON COLUMN raamaesha.integration_executions.idempotency_key IS
'Optional caller-supplied key used to prevent duplicate logical executions within an integration.';

COMMENT ON COLUMN raamaesha.integration_executions.correlation_id IS
'Optional identifier used to correlate the execution across workflows, services, requests, and future distributed tracing systems.';

COMMENT ON COLUMN raamaesha.integration_executions.retry_count IS
'Number of retry attempts recorded for the logical execution. Retry scheduling and execution belong to the runtime layer.';

COMMENT ON COLUMN raamaesha.integration_executions.next_retry_at IS
'Optional timestamp indicating when the runtime may next attempt the execution.';

COMMENT ON COLUMN raamaesha.integration_executions.started_at IS
'Timestamp when execution processing actually started.';

COMMENT ON COLUMN raamaesha.integration_executions.completed_at IS
'Timestamp when the execution reached a terminal state.';

COMMENT ON COLUMN raamaesha.integration_executions.duration_ms IS
'Execution duration in milliseconds when available.';

COMMENT ON COLUMN raamaesha.integration_executions.provider_request_id IS
'Optional non-secret request identifier returned or assigned by the external provider.';

COMMENT ON COLUMN raamaesha.integration_executions.provider_response_id IS
'Optional non-secret response identifier associated with the provider interaction.';

COMMENT ON COLUMN raamaesha.integration_executions.http_status_code IS
'Optional HTTP response status code associated with the execution.';

COMMENT ON COLUMN raamaesha.integration_executions.request_metadata IS
'Safe operational metadata about the request. Secrets, credentials, authorization headers, and sensitive payloads must not be stored here.';

COMMENT ON COLUMN raamaesha.integration_executions.response_metadata IS
'Safe operational metadata about the response. Secrets, credentials, authorization headers, and sensitive payloads must not be stored here.';

COMMENT ON COLUMN raamaesha.integration_executions.error_code IS
'Optional non-secret machine-readable error code.';

COMMENT ON COLUMN raamaesha.integration_executions.error_category IS
'Optional non-secret classification of the execution failure.';

COMMENT ON COLUMN raamaesha.integration_executions.error_message IS
'Optional non-secret diagnostic error message.';

COMMENT ON COLUMN raamaesha.integration_executions.metadata IS
'Extensible execution metadata for future platform capabilities.';


-- =============================================================================
-- Integration Execution Indexes
-- =============================================================================

CREATE INDEX idx_integration_executions_integration
    ON raamaesha.integration_executions (integration_id);

CREATE INDEX idx_integration_executions_connection
    ON raamaesha.integration_executions (connection_id);

CREATE INDEX idx_integration_executions_status
    ON raamaesha.integration_executions (status);

CREATE INDEX idx_integration_executions_operation
    ON raamaesha.integration_executions (operation_code);

CREATE INDEX idx_integration_executions_correlation
    ON raamaesha.integration_executions (correlation_id)
    WHERE correlation_id IS NOT NULL;

CREATE INDEX idx_integration_executions_created_at
    ON raamaesha.integration_executions (created_at);

CREATE INDEX idx_integration_executions_next_retry
    ON raamaesha.integration_executions (next_retry_at)
    WHERE next_retry_at IS NOT NULL;

CREATE INDEX idx_integration_executions_failed
    ON raamaesha.integration_executions (integration_id, created_at DESC)
    WHERE status = 'failed';

CREATE INDEX idx_integration_executions_pending
    ON raamaesha.integration_executions (integration_id, created_at)
    WHERE status = 'pending';


-- =============================================================================
-- Production Integrity : Idempotency
-- =============================================================================
--
-- An idempotency key is unique within an integration.
-- NULL values remain unrestricted.
-- =============================================================================

CREATE UNIQUE INDEX ux_integration_executions_integration_idempotency
    ON raamaesha.integration_executions (integration_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;


-- =============================================================================
-- Audit Trigger
-- =============================================================================

CREATE TRIGGER trg_integration_executions_set_updated_at
BEFORE UPDATE
ON raamaesha.integration_executions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;