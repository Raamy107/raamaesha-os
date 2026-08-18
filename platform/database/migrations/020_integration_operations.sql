-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 020_integration_operations.sql
-- Module    : Integration Operation Registry
--
-- Purpose:
--   Creates the persistent registry of operations supported by organization
--   integrations.
--
-- Responsibilities:
--   - Integration operation definitions
--   - Stable operation identification
--   - Operation categorization
--   - Operation lifecycle management
--   - Multi-tenant ownership through integrations
--   - Extensible operational metadata
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
--          +----------------------+
--          |                      |
--          v                      v
--   Integration Connection   Integration Operation
--                                   |
--                                   v
--                          Integration Execution
--                                   |
--                                   v
--                            Runtime / Nandi AI
--
-- Design Principles:
--   - Provider agnostic
--   - Multi-tenant through integration ownership
--   - Stable operation codes
--   - One operation code per integration
--   - Extensible categories
--   - Extensible JSONB metadata
--   - Soft deletion
--   - No plaintext secrets
--   - No provider-specific business logic
--   - No execution logic
--   - No request/response payload storage
--   - Compatible with future Tool Gateway and AI Runtime capabilities
--
-- Dependencies:
--   - 001_extensions.sql
--   - 003_schema_core.sql
--   - 007_identity_actor.sql
--   - 013_audit_infrastructure.sql
--   - 018_integration_platform.sql
--   - 019_integration_execution.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Integration Operations
-- =============================================================================
--
-- Represents a reusable logical operation supported by an organization-owned
-- integration.
--
-- Examples:
--   customer.create
--   customer.update
--   invoice.create
--   payment.capture
--   inventory.sync
--
-- These are examples only. Migration 020 does not seed provider-specific
-- operations.
--
-- The operation registry describes what an integration can do.
-- It does not execute the operation.
--
-- Actual execution records are maintained by:
--
--   raamaesha.integration_executions
--
-- =============================================================================

CREATE TABLE raamaesha.integration_operations
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    integration_id
        UUID
        NOT NULL,

    code
        TEXT
        NOT NULL,

    name
        TEXT
        NOT NULL,

    description
        TEXT,

    category
        TEXT
        NOT NULL,

    is_active
        BOOLEAN
        NOT NULL
        DEFAULT TRUE,

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

    CONSTRAINT pk_integration_operations
        PRIMARY KEY (id),


    -- =========================================================================
    -- Operation Identity
    -- =========================================================================

    CONSTRAINT uq_integration_operations_integration_code
        UNIQUE (integration_id, code),


    -- =========================================================================
    -- Integration Ownership
    -- =========================================================================
    --
    -- Every operation belongs to exactly one organization-owned integration.
    -- Deleting an integration is intentionally restricted because operations
    -- represent persistent capability definitions and may have historical
    -- execution references.
    -- =========================================================================

    CONSTRAINT fk_integration_operations_integration
        FOREIGN KEY (integration_id)
        REFERENCES raamaesha.integrations (id)
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Audit Actor References
    -- =========================================================================

    CONSTRAINT fk_integration_operations_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT fk_integration_operations_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,


    -- =========================================================================
    -- Validation
    -- =========================================================================

    CONSTRAINT ck_integration_operations_code_not_blank
        CHECK (length(trim(code)) > 0),

    CONSTRAINT ck_integration_operations_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_integration_operations_category_not_blank
        CHECK (length(trim(category)) > 0),

    CONSTRAINT ck_integration_operations_description_not_blank
        CHECK (
            description IS NULL
            OR length(trim(description)) > 0
        ),

    CONSTRAINT ck_integration_operations_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);


-- =============================================================================
-- Integration Operation Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.integration_operations IS
'Registry of logical operations supported by organization-owned integrations. Defines integration capabilities without executing them.';


COMMENT ON COLUMN raamaesha.integration_operations.id IS
'Globally unique identifier for the integration operation.';


COMMENT ON COLUMN raamaesha.integration_operations.integration_id IS
'Organization-owned integration that provides this operation.';


COMMENT ON COLUMN raamaesha.integration_operations.code IS
'Stable provider-independent operation code within the parent integration.';


COMMENT ON COLUMN raamaesha.integration_operations.name IS
'Human-readable name of the integration operation.';


COMMENT ON COLUMN raamaesha.integration_operations.description IS
'Optional human-readable description of the operation and its intended purpose.';


COMMENT ON COLUMN raamaesha.integration_operations.category IS
'Extensible logical category used to classify the operation for discovery, organization, and future capability routing.';


COMMENT ON COLUMN raamaesha.integration_operations.is_active IS
'Indicates whether the operation is currently available for new runtime execution.';


COMMENT ON COLUMN raamaesha.integration_operations.metadata IS
'Extensible non-secret operation metadata for provider-specific, platform, discovery, and future capability requirements. Plaintext secrets must not be stored here.';


COMMENT ON COLUMN raamaesha.integration_operations.created_at IS
'Timestamp when the integration operation was created.';


COMMENT ON COLUMN raamaesha.integration_operations.updated_at IS
'Timestamp when the integration operation was most recently updated.';


COMMENT ON COLUMN raamaesha.integration_operations.created_by IS
'Actor responsible for creating the integration operation when known.';


COMMENT ON COLUMN raamaesha.integration_operations.updated_by IS
'Actor responsible for the most recent update when known.';


COMMENT ON COLUMN raamaesha.integration_operations.deleted_at IS
'Soft deletion timestamp. NULL indicates that the integration operation has not been soft deleted.';


-- =============================================================================
-- Integration Operation Indexes
-- =============================================================================

CREATE INDEX idx_integration_operations_integration
    ON raamaesha.integration_operations (integration_id);


CREATE INDEX idx_integration_operations_category
    ON raamaesha.integration_operations (category);


CREATE INDEX idx_integration_operations_active
    ON raamaesha.integration_operations (is_active);


CREATE INDEX idx_integration_operations_deleted_at
    ON raamaesha.integration_operations (deleted_at);


-- =============================================================================
-- Active Operation Discovery
-- =============================================================================
--
-- Supports efficient runtime discovery of operations that are currently
-- available and have not been soft deleted.
-- =============================================================================

CREATE INDEX idx_integration_operations_active_discovery
    ON raamaesha.integration_operations (integration_id, category, code)
    WHERE is_active = TRUE
      AND deleted_at IS NULL;


-- =============================================================================
-- Audit Trigger
-- =============================================================================
--
-- Reuses the platform-wide audit trigger established by Migration 013.
-- =============================================================================

CREATE TRIGGER trg_integration_operations_set_updated_at
BEFORE UPDATE
ON raamaesha.integration_operations
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;