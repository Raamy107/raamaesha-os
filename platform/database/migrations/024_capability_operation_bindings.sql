-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 024_capability_operation_bindings.sql
-- Module    : Capability Operation Bindings
--
-- Purpose:
--   Creates the registry binding reusable platform capabilities to
--   organization-owned integration operations.
--
-- Responsibilities:
--   - Capability to integration operation relationships
--   - Optional capability API references
--   - Optional capability event references
--   - Binding lifecycle management
--   - Binding discovery
--   - Extensible non-secret metadata
--   - Audit actor references
--   - Soft deletion
--
-- Architecture:
--
--   Capability Registry (022)
--          |
--          v
--   Capability Interfaces (023)
--          |
--          v
--   Capability Operation Binding (024)
--          |
--          v
--   Integration Operation (020)
--          |
--          v
--   Operation Contract (021)
--          |
--          v
--   Runtime / Tool Gateway
--          |
--          v
--   Nandi AI Runtime
--
-- Design Principles:
--   - Platform-level capability definitions remain reusable
--   - Organization ownership remains with integration operations
--   - Provider agnostic
--   - Explicit capability-to-operation relationships
--   - Optional API interface association
--   - Optional event interface association
--   - Stable machine-readable binding identity
--   - Extensible JSONB metadata
--   - No plaintext secrets
--   - No execution logic
--   - No workflow execution
--   - No worker scheduling
--   - No queue management
--   - No runtime health-check execution
--   - Compatible with future Tool Gateway
--   - Compatible with Nandi AI discovery and orchestration
--
-- Dependencies:
--   - 001_extensions.sql
--   - 003_schema_core.sql
--   - 007_identity_actor.sql
--   - 013_audit_infrastructure.sql
--   - 020_integration_operations.sql
--   - 022_capability_registry.sql
--   - 023_capability_interfaces.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- ENUM : Capability Operation Binding Status
-- =============================================================================

CREATE TYPE public.capability_operation_binding_status AS ENUM
(
    'draft',
    'active',
    'disabled',
    'deprecated'
);

COMMENT ON TYPE public.capability_operation_binding_status IS
'Lifecycle state of a binding between a reusable capability and an integration operation.';


-- =============================================================================
-- Capability Operation Bindings
-- =============================================================================
--
-- Represents the relationship between a reusable platform capability and an
-- organization-owned integration operation.
--
-- This table does not execute the operation.
--
-- It establishes the persistent metadata relationship required by future
-- Tool Gateway, runtime discovery, workflow, and Nandi AI layers.
--
-- =============================================================================

CREATE TABLE raamaesha.capability_operation_bindings
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    capability_id
        UUID
        NOT NULL,

    operation_id
        UUID
        NOT NULL,

    capability_api_id
        UUID,

    capability_event_id
        UUID,

    status
        public.capability_operation_binding_status
        NOT NULL
        DEFAULT 'draft',

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

    CONSTRAINT pk_capability_operation_bindings
        PRIMARY KEY (id),


    -- =========================================================================
    -- Capability Relationship
    -- =========================================================================

    CONSTRAINT fk_capability_operation_bindings_capability
        FOREIGN KEY (capability_id)
        REFERENCES raamaesha.capabilities (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Integration Operation Relationship
    -- =========================================================================

    CONSTRAINT fk_capability_operation_bindings_operation
        FOREIGN KEY (operation_id)
        REFERENCES raamaesha.integration_operations (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Capability API Relationship
    -- =========================================================================

    CONSTRAINT fk_capability_operation_bindings_api
        FOREIGN KEY (capability_api_id)
        REFERENCES raamaesha.capability_apis (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- Capability Event Relationship
    -- =========================================================================

    CONSTRAINT fk_capability_operation_bindings_event
        FOREIGN KEY (capability_event_id)
        REFERENCES raamaesha.capability_events (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- Audit Actor Relationships
    -- =========================================================================

    CONSTRAINT fk_capability_operation_bindings_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_capability_operation_bindings_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- Binding Identity
    -- =========================================================================

    CONSTRAINT uq_capability_operation_bindings_relationship
        UNIQUE
        (
            capability_id,
            operation_id,
            capability_api_id,
            capability_event_id
        ),


    -- =========================================================================
    -- Metadata Integrity
    -- =========================================================================

    CONSTRAINT ck_capability_operation_bindings_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        ),


    -- =========================================================================
    -- Interface Association Integrity
    -- =========================================================================
    --
    -- A binding must identify at least one interface when an explicit
    -- interface association is required by the runtime.
    --
    -- The binding itself may remain interface-neutral for future capability
    -- relationships that are not API/event specific.
    -- =========================================================================

    CONSTRAINT ck_capability_operation_bindings_interface_reference
        CHECK (
            capability_api_id IS NOT NULL
            OR capability_event_id IS NOT NULL
            OR
            (
                capability_api_id IS NULL
                AND capability_event_id IS NULL
            )
        )

);


-- =============================================================================
-- Capability Operation Binding Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.capability_operation_bindings IS
'Persistent registry binding reusable RaamaEsha OS capabilities to organization-owned integration operations and optional capability interfaces.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.id IS
'Globally unique identifier for the capability operation binding.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.capability_id IS
'Reusable platform capability associated with the integration operation.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.operation_id IS
'Organization-owned integration operation associated with the capability.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.capability_api_id IS
'Optional capability API interface associated with the binding.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.capability_event_id IS
'Optional capability event interface associated with the binding.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.status IS
'Lifecycle state of the capability operation binding.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.metadata IS
'Extensible non-secret metadata for capability discovery, Tool Gateway integration, and future runtime requirements. Plaintext secrets must not be stored here.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.created_at IS
'Timestamp when the capability operation binding was created.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.updated_at IS
'Timestamp when the capability operation binding was most recently updated.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.created_by IS
'Actor responsible for creating the capability operation binding when known.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.updated_by IS
'Actor responsible for the most recent capability operation binding update when known.';


COMMENT ON COLUMN raamaesha.capability_operation_bindings.deleted_at IS
'Soft deletion timestamp. NULL indicates that the binding has not been soft deleted.';


-- =============================================================================
-- Capability Operation Binding Indexes
-- =============================================================================

CREATE INDEX idx_capability_operation_bindings_capability
    ON raamaesha.capability_operation_bindings
    (capability_id);


CREATE INDEX idx_capability_operation_bindings_operation
    ON raamaesha.capability_operation_bindings
    (operation_id);


CREATE INDEX idx_capability_operation_bindings_api
    ON raamaesha.capability_operation_bindings
    (capability_api_id);


CREATE INDEX idx_capability_operation_bindings_event
    ON raamaesha.capability_operation_bindings
    (capability_event_id);


CREATE INDEX idx_capability_operation_bindings_status
    ON raamaesha.capability_operation_bindings
    (status);


CREATE INDEX idx_capability_operation_bindings_deleted_at
    ON raamaesha.capability_operation_bindings
    (deleted_at);


-- =============================================================================
-- Active Capability Operation Discovery
-- =============================================================================

CREATE INDEX idx_capability_operation_bindings_active_discovery
    ON raamaesha.capability_operation_bindings
    (
        capability_id,
        operation_id
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Production Integrity : One Active Binding
-- =============================================================================

CREATE UNIQUE INDEX ux_capability_operation_bindings_one_active
    ON raamaesha.capability_operation_bindings
    (
        capability_id,
        operation_id,
        capability_api_id,
        capability_event_id
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Audit Trigger
-- =============================================================================

CREATE TRIGGER trg_capability_operation_bindings_set_updated_at
BEFORE UPDATE
ON raamaesha.capability_operation_bindings
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;