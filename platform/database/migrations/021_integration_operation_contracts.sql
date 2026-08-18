-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 021_integration_operation_contracts.sql
-- Module    : Integration Operation Contracts
--
-- Purpose:
--   Creates the versioned contract registry for integration operations.
--
-- Responsibilities:
--   - Versioned integration operation contracts
--   - Input contract definitions
--   - Output contract definitions
--   - Execution capability metadata
--   - Runtime execution hints
--   - Contract lifecycle management
--   - Contract discovery
--   - Tenant-safe ownership through integration operations
--   - Extensible JSONB metadata
--   - Soft deletion
--   - Audit actor references
--
-- Architecture:
--
--   Integration Provider
--          |
--          v
--   Organization Integration
--          |
--          v
--   Integration Operation
--          |
--          v
--   Operation Contract
--       /          \
--      v            v
-- Input Schema    Output Schema
--          |
--          v
--   Runtime / Tool Gateway
--          |
--          v
--       Execution
--          |
--          v
--       Nandi AI
--
-- Design Principles:
--   - Provider agnostic
--   - Multi-tenant through integration ownership
--   - Versioned contracts
--   - Stable operation identity remains in Migration 020
--   - Contract changes do not mutate historical contract definitions
--   - One active contract version per operation
--   - Input and output definitions are extensible JSONB
--   - Runtime hints are advisory, not execution logic
--   - No plaintext secrets
--   - No provider-specific business logic
--   - No request/response payload storage
--   - No workflow execution
--   - No worker scheduling
--   - Compatible with future Tool Gateway capabilities
--   - Compatible with Nandi AI discovery and orchestration
--
-- Dependencies:
--   - 001_extensions.sql
--   - 003_schema_core.sql
--   - 007_identity_actor.sql
--   - 013_audit_infrastructure.sql
--   - 018_integration_platform.sql
--   - 019_integration_execution.sql
--   - 020_integration_operations.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- ENUM : Integration Operation Contract Status
-- =============================================================================

CREATE TYPE public.integration_operation_contract_status AS ENUM
(
    'draft',
    'active',
    'deprecated',
    'disabled'
);

COMMENT ON TYPE public.integration_operation_contract_status IS
'Lifecycle state of a versioned integration operation contract.';


-- =============================================================================
-- Integration Operation Contracts
-- =============================================================================
--
-- Represents one version of the contract exposed by an integration operation.
--
-- The operation itself is defined by Migration 020.
--
-- This table defines the machine-readable contract used by future runtime,
-- Tool Gateway, API, workflow, and Nandi AI capabilities.
--
-- Contract versions are immutable in meaning. A new contract version should
-- be created when the externally visible contract changes materially.
--
-- The database does not execute, validate, transform, or schedule operations.
-- It only persists the contract metadata required by those runtime layers.
-- =============================================================================

CREATE TABLE raamaesha.integration_operation_contracts
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    operation_id
        UUID
        NOT NULL,

    version
        INTEGER
        NOT NULL,

    status
        public.integration_operation_contract_status
        NOT NULL
        DEFAULT 'draft',

    input_schema
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    output_schema
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    execution_metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    runtime_hints
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

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

    deleted_at
        TIMESTAMPTZ,


    -- =========================================================================
    -- Primary Key
    -- =========================================================================

    CONSTRAINT pk_integration_operation_contracts
        PRIMARY KEY (id),


    -- =========================================================================
    -- Contract Identity
    -- =========================================================================

    CONSTRAINT uq_integration_operation_contracts_operation_version
        UNIQUE (operation_id, version),


    -- =========================================================================
    -- Operation Ownership
    -- =========================================================================
    --
    -- Every contract belongs to exactly one integration operation.
    --
    -- Restricting deletion protects contract history and prevents accidental
    -- removal of definitions that may be referenced by runtime history.
    -- =========================================================================

    CONSTRAINT fk_integration_operation_contracts_operation
        FOREIGN KEY (operation_id)
        REFERENCES raamaesha.integration_operations (id)
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Audit Actor References
    -- =========================================================================

    CONSTRAINT fk_integration_operation_contracts_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT fk_integration_operation_contracts_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,


    -- =========================================================================
    -- Validation
    -- =========================================================================

    CONSTRAINT ck_integration_operation_contracts_version_positive
        CHECK (version > 0),


    CONSTRAINT ck_integration_operation_contracts_input_schema_object
        CHECK (jsonb_typeof(input_schema) = 'object'),


    CONSTRAINT ck_integration_operation_contracts_output_schema_object
        CHECK (jsonb_typeof(output_schema) = 'object'),


    CONSTRAINT ck_integration_operation_contracts_execution_metadata_object
        CHECK (jsonb_typeof(execution_metadata) = 'object'),


    CONSTRAINT ck_integration_operation_contracts_runtime_hints_object
        CHECK (jsonb_typeof(runtime_hints) = 'object'),


    CONSTRAINT ck_integration_operation_contracts_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);


-- =============================================================================
-- Integration Operation Contract Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.integration_operation_contracts IS
'Versioned machine-readable contracts defining the inputs, outputs, execution metadata, and runtime hints of integration operations.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.id IS
'Globally unique identifier for the operation contract version.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.operation_id IS
'Integration operation to which this contract version belongs.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.version IS
'Positive contract version number scoped to the parent integration operation.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.status IS
'Lifecycle state of the contract version.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.input_schema IS
'Machine-readable non-secret definition of the operation input structure. Intended to support future validation, Tool Gateway discovery, and AI capability discovery.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.output_schema IS
'Machine-readable non-secret definition of the operation output structure. Intended to support future runtime handling, Tool Gateway discovery, and AI capability discovery.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.execution_metadata IS
'Non-secret metadata describing execution characteristics or capabilities. This metadata is descriptive and does not contain execution logic.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.runtime_hints IS
'Non-secret advisory hints for future runtime layers such as timeout, retry, batching, concurrency, or execution preferences. Runtime behavior remains outside the database.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.metadata IS
'Extensible non-secret contract metadata for platform, discovery, provider-neutral, and future capability requirements. Plaintext secrets must not be stored here.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.created_at IS
'Timestamp when the contract version was created.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.updated_at IS
'Timestamp when the contract version was most recently updated.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.created_by IS
'Actor responsible for creating the contract version when known.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.updated_by IS
'Actor responsible for the most recent contract update when known.';


COMMENT ON COLUMN raamaesha.integration_operation_contracts.deleted_at IS
'Soft deletion timestamp. NULL indicates that the contract version has not been soft deleted.';


-- =============================================================================
-- Integration Operation Contract Indexes
-- =============================================================================

CREATE INDEX idx_integration_operation_contracts_operation
    ON raamaesha.integration_operation_contracts (operation_id);


CREATE INDEX idx_integration_operation_contracts_status
    ON raamaesha.integration_operation_contracts (status);


CREATE INDEX idx_integration_operation_contracts_version
    ON raamaesha.integration_operation_contracts (operation_id, version DESC);


CREATE INDEX idx_integration_operation_contracts_deleted_at
    ON raamaesha.integration_operation_contracts (deleted_at);


-- =============================================================================
-- Active Contract Discovery
-- =============================================================================
--
-- Supports efficient discovery of currently active, non-deleted contracts.
-- =============================================================================

CREATE INDEX idx_integration_operation_contracts_active_discovery
    ON raamaesha.integration_operation_contracts
    (
        operation_id,
        version DESC
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Production Integrity : One Active Contract Per Operation
-- =============================================================================
--
-- Only one contract version may be active for an operation at any given time.
--
-- Historical versions remain available as draft, deprecated, disabled, or
-- soft-deleted records.
--
-- This prevents ambiguous runtime contract discovery.
-- =============================================================================

CREATE UNIQUE INDEX ux_integration_operation_contracts_one_active
    ON raamaesha.integration_operation_contracts (operation_id)
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Audit Trigger
-- =============================================================================
--
-- Reuses the platform-wide audit trigger established by Migration 013.
-- =============================================================================

CREATE TRIGGER trg_integration_operation_contracts_set_updated_at
BEFORE UPDATE
ON raamaesha.integration_operation_contracts
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;