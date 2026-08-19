-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 022_capability_registry.sql
-- Module    : Capability Registry
--
-- Purpose:
--   Creates the central reusable registry of RaamaEsha OS platform
--   capabilities.
--
-- Responsibilities:
--   - Platform capability identity
--   - Capability versioning
--   - Capability lifecycle management
--   - Capability health status
--   - Capability discovery
--   - Extensible non-secret metadata
--   - Audit actor references
--   - Soft deletion
--
-- Architecture:
--
--   Capability Registry
--          |
--          +--------------------+
--          |                    |
--          v                    v
--     Tool Gateway          Future APIs
--          |
--          v
--   Operation Contracts
--          |
--          v
--   Integration Operations
--          |
--          v
--   Integration Executions
--          |
--          v
--      Nandi AI Runtime
--
-- Design Principles:
--   - Platform-level and reusable
--   - Provider agnostic
--   - Multi-tenant by reuse, not ownership
--   - Versioned
--   - Stable machine-readable capability codes
--   - One active version per capability
--   - Extensible JSONB metadata
--   - No plaintext secrets
--   - No API execution logic
--   - No event processing logic
--   - No workflow execution
--   - No worker scheduling
--   - No health-check execution
--   - Compatible with future Tool Gateway
--   - Compatible with Nandi AI discovery and orchestration
--
-- Dependencies:
--   - 001_extensions.sql
--   - 003_schema_core.sql
--   - 007_identity_actor.sql
--   - 013_audit_infrastructure.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- ENUM : Capability Status
-- =============================================================================

CREATE TYPE public.capability_status AS ENUM
(
    'draft',
    'active',
    'deprecated',
    'disabled'
);

COMMENT ON TYPE public.capability_status IS
'Lifecycle state of a versioned RaamaEsha OS platform capability.';


-- =============================================================================
-- ENUM : Capability Health Status
-- =============================================================================

CREATE TYPE public.capability_health_status AS ENUM
(
    'unknown',
    'healthy',
    'degraded',
    'unhealthy'
);

COMMENT ON TYPE public.capability_health_status IS
'Current descriptive health state of a platform capability. Health monitoring
and health-check execution remain outside the database layer.';


-- =============================================================================
-- Capability Registry
-- =============================================================================
--
-- Represents one version of a reusable RaamaEsha OS platform capability.
--
-- Capability definitions are platform-level and are intentionally not owned
-- by an organization.
--
-- Organizations consume capabilities through business applications,
-- integrations, operation contracts, and future Tool Gateway/runtime layers.
--
-- A new version should be created when the externally discoverable capability
-- definition changes materially.
--
-- The database stores capability identity and metadata only. It does not
-- execute capability logic.
-- =============================================================================

CREATE TABLE raamaesha.capabilities
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    code
        CITEXT
        NOT NULL,

    name
        TEXT
        NOT NULL,

    description
        TEXT,

    version
        INTEGER
        NOT NULL
        DEFAULT 1,

    status
        public.capability_status
        NOT NULL
        DEFAULT 'draft',

    health_status
        public.capability_health_status
        NOT NULL
        DEFAULT 'unknown',

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

    CONSTRAINT pk_capabilities
        PRIMARY KEY (id),


    -- =========================================================================
    -- Capability Identity
    -- =========================================================================

    CONSTRAINT uq_capabilities_code_version
        UNIQUE (code, version),


    -- =========================================================================
    -- Capability Code
    -- =========================================================================

    CONSTRAINT ck_capabilities_code
        CHECK (
            code ~ '^[a-z0-9]+(\.[a-z0-9_]+)*$'
        ),


    -- =========================================================================
    -- Capability Name
    -- =========================================================================

    CONSTRAINT ck_capabilities_name_not_blank
        CHECK (
            length(trim(name)) > 0
        ),


    -- =========================================================================
    -- Capability Version
    -- =========================================================================

    CONSTRAINT ck_capabilities_version_positive
        CHECK (
            version >= 1
        ),


    -- =========================================================================
    -- Metadata Integrity
    -- =========================================================================

    CONSTRAINT ck_capabilities_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )

);


-- =============================================================================
-- Foreign Keys
-- =============================================================================

ALTER TABLE raamaesha.capabilities
    ADD CONSTRAINT fk_capabilities_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL;


ALTER TABLE raamaesha.capabilities
    ADD CONSTRAINT fk_capabilities_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL;


-- =============================================================================
-- Capability Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.capabilities IS
'Central registry of reusable RaamaEsha OS platform capability definitions.';


COMMENT ON COLUMN raamaesha.capabilities.id IS
'Globally unique identifier for the capability version.';


COMMENT ON COLUMN raamaesha.capabilities.code IS
'Stable provider-independent machine-readable capability code.';


COMMENT ON COLUMN raamaesha.capabilities.name IS
'Human-readable name of the platform capability.';


COMMENT ON COLUMN raamaesha.capabilities.description IS
'Optional human-readable description of the capability and its intended purpose.';


COMMENT ON COLUMN raamaesha.capabilities.version IS
'Integer version of the capability definition. A new version represents a materially changed externally discoverable capability definition.';


COMMENT ON COLUMN raamaesha.capabilities.status IS
'Lifecycle state of the capability version.';


COMMENT ON COLUMN raamaesha.capabilities.health_status IS
'Current descriptive health state of the capability. Runtime health monitoring remains outside the database.';


COMMENT ON COLUMN raamaesha.capabilities.metadata IS
'Extensible non-secret capability metadata for platform discovery, Tool Gateway integration, and future capability requirements. Plaintext secrets must not be stored here.';


COMMENT ON COLUMN raamaesha.capabilities.created_at IS
'Timestamp when the capability version was created.';


COMMENT ON COLUMN raamaesha.capabilities.updated_at IS
'Timestamp when the capability version was most recently updated.';


COMMENT ON COLUMN raamaesha.capabilities.created_by IS
'Actor responsible for creating the capability version when known.';


COMMENT ON COLUMN raamaesha.capabilities.updated_by IS
'Actor responsible for the most recent capability update when known.';


COMMENT ON COLUMN raamaesha.capabilities.deleted_at IS
'Soft deletion timestamp. NULL indicates that the capability version has not been soft deleted.';


-- =============================================================================
-- Capability Registry Indexes
-- =============================================================================

CREATE INDEX idx_capabilities_code
    ON raamaesha.capabilities (code);


CREATE INDEX idx_capabilities_status
    ON raamaesha.capabilities (status);


CREATE INDEX idx_capabilities_health_status
    ON raamaesha.capabilities (health_status);


CREATE INDEX idx_capabilities_version
    ON raamaesha.capabilities (code, version DESC);


CREATE INDEX idx_capabilities_deleted_at
    ON raamaesha.capabilities (deleted_at);


-- =============================================================================
-- Active Capability Discovery
-- =============================================================================
--
-- Supports efficient discovery of the currently active, non-deleted
-- capability versions.
-- =============================================================================

CREATE INDEX idx_capabilities_active_discovery
    ON raamaesha.capabilities
    (
        code,
        version DESC
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Production Integrity: One Active Version Per Capability
-- =============================================================================
--
-- Only one version of a capability may be active at any given time.
--
-- Historical versions remain available as draft, deprecated, disabled,
-- or soft-deleted records.
--
-- This prevents ambiguous capability discovery by future Tool Gateway and
-- Nandi AI runtime layers.
-- =============================================================================

CREATE UNIQUE INDEX ux_capabilities_one_active
    ON raamaesha.capabilities (code)
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Audit Trigger
-- =============================================================================
--
-- Reuses the platform-wide audit timestamp trigger established by Migration
-- 013.
-- =============================================================================

CREATE TRIGGER trg_capabilities_set_updated_at
BEFORE UPDATE
ON raamaesha.capabilities
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;