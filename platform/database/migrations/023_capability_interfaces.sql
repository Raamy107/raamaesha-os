-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 023_capability_interfaces.sql
-- Module    : Capability Interfaces
--
-- Purpose:
--   Creates the API and Event interface registries associated with reusable
--   RaamaEsha OS platform capabilities.
--
-- Responsibilities:
--   - Capability API definitions
--   - Capability API versioning
--   - Capability API lifecycle management
--   - Capability API discovery
--   - Capability Event definitions
--   - Capability Event versioning
--   - Capability Event lifecycle management
--   - Capability Event discovery
--   - Optional authorization permission references
--   - Extensible non-secret metadata
--   - Audit actor references
--   - Soft deletion
--
-- Architecture:
--
--   Capability Registry (022)
--          |
--          +-------------------------+
--          |                         |
--          v                         v
--   Capability APIs           Capability Events
--          |                         |
--          +------------+------------+
--                       |
--                       v
--                 Tool Gateway
--                       |
--                       v
--                 Nandi AI Runtime
--
-- Authorization:
--
--   Capability APIs / Events
--             |
--             v
--   Existing Permission Registry
--             |
--             v
--      raamaesha.permissions
--
-- Design Principles:
--   - Platform-level and reusable
--   - Provider agnostic
--   - Capability-owned
--   - Versioned
--   - Stable machine-readable codes
--   - One active version per interface
--   - Extensible JSONB metadata
--   - No plaintext secrets
--   - No API execution logic
--   - No event processing logic
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
--   - 010_identity_permissions.sql
--   - 013_audit_infrastructure.sql
--   - 022_capability_registry.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- ENUM : Capability API Status
-- =============================================================================

CREATE TYPE public.capability_api_status AS ENUM
(
    'draft',
    'active',
    'deprecated',
    'disabled'
);

COMMENT ON TYPE public.capability_api_status IS
'Lifecycle state of a versioned capability API definition.';


-- =============================================================================
-- ENUM : Capability API HTTP Method
-- =============================================================================

CREATE TYPE public.capability_api_http_method AS ENUM
(
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS'
);

COMMENT ON TYPE public.capability_api_http_method IS
'HTTP method exposed by a capability API definition.';


-- =============================================================================
-- ENUM : Capability Event Status
-- =============================================================================

CREATE TYPE public.capability_event_status AS ENUM
(
    'draft',
    'active',
    'deprecated',
    'disabled'
);

COMMENT ON TYPE public.capability_event_status IS
'Lifecycle state of a versioned capability event definition.';


-- =============================================================================
-- ENUM : Capability Event Direction
-- =============================================================================

CREATE TYPE public.capability_event_direction AS ENUM
(
    'published',
    'subscribed'
);

COMMENT ON TYPE public.capability_event_direction IS
'Direction of a capability event relative to RaamaEsha OS.';


-- =============================================================================
-- Capability APIs
-- =============================================================================
--
-- Represents one version of an API interface exposed by a reusable platform
-- capability.
--
-- The database stores API identity, discovery metadata, routing information,
-- and authorization references only.
--
-- API execution remains outside the database layer.
-- =============================================================================

CREATE TABLE raamaesha.capability_apis
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    capability_id
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

    version
        INTEGER
        NOT NULL
        DEFAULT 1,

    http_method
        public.capability_api_http_method
        NOT NULL,

    path
        TEXT
        NOT NULL,

    status
        public.capability_api_status
        NOT NULL
        DEFAULT 'draft',

    permission_id
        UUID,

    request_schema
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    response_schema
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

    CONSTRAINT pk_capability_apis
        PRIMARY KEY (id),


    -- =========================================================================
    -- Capability Relationship
    -- =========================================================================

    CONSTRAINT fk_capability_apis_capability
        FOREIGN KEY (capability_id)
        REFERENCES raamaesha.capabilities (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Permission Relationship
    -- =========================================================================

    CONSTRAINT fk_capability_apis_permission
        FOREIGN KEY (permission_id)
        REFERENCES raamaesha.permissions (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- Audit Actor Relationships
    -- =========================================================================

    CONSTRAINT fk_capability_apis_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_capability_apis_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- API Identity
    -- =========================================================================

    CONSTRAINT uq_capability_apis_capability_code_version
        UNIQUE (capability_id, code, version),


    -- =========================================================================
    -- API Code
    -- =========================================================================

    CONSTRAINT ck_capability_apis_code
        CHECK (
            code ~ '^[a-z0-9]+(\.[a-z0-9_]+)*$'
        ),


    -- =========================================================================
    -- API Name
    -- =========================================================================

    CONSTRAINT ck_capability_apis_name_not_blank
        CHECK (
            length(trim(name)) > 0
        ),


    -- =========================================================================
    -- API Version
    -- =========================================================================

    CONSTRAINT ck_capability_apis_version_positive
        CHECK (
            version >= 1
        ),


    -- =========================================================================
    -- API Path
    -- =========================================================================

    CONSTRAINT ck_capability_apis_path_not_blank
        CHECK (
            length(trim(path)) > 0
        ),


    -- =========================================================================
    -- API Path Format
    -- =========================================================================

    CONSTRAINT ck_capability_apis_path_starts_with_slash
        CHECK (
            left(trim(path), 1) = '/'
        ),


    -- =========================================================================
    -- Request Schema Integrity
    -- =========================================================================

    CONSTRAINT ck_capability_apis_request_schema_object
        CHECK (
            jsonb_typeof(request_schema) = 'object'
        ),


    -- =========================================================================
    -- Response Schema Integrity
    -- =========================================================================

    CONSTRAINT ck_capability_apis_response_schema_object
        CHECK (
            jsonb_typeof(response_schema) = 'object'
        ),


    -- =========================================================================
    -- Metadata Integrity
    -- =========================================================================

    CONSTRAINT ck_capability_apis_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )

);


-- =============================================================================
-- Capability API Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.capability_apis IS
'Registry of versioned API interfaces exposed by reusable RaamaEsha OS capabilities.';


COMMENT ON COLUMN raamaesha.capability_apis.id IS
'Globally unique identifier for the capability API version.';


COMMENT ON COLUMN raamaesha.capability_apis.capability_id IS
'Capability definition that owns this API interface.';


COMMENT ON COLUMN raamaesha.capability_apis.code IS
'Stable machine-readable API code within the owning capability.';


COMMENT ON COLUMN raamaesha.capability_apis.name IS
'Human-readable name of the capability API.';


COMMENT ON COLUMN raamaesha.capability_apis.description IS
'Optional human-readable description of the API interface and its intended purpose.';


COMMENT ON COLUMN raamaesha.capability_apis.version IS
'Integer version of the API definition. A new version represents a materially changed externally discoverable API contract.';


COMMENT ON COLUMN raamaesha.capability_apis.http_method IS
'HTTP method used by the API interface.';


COMMENT ON COLUMN raamaesha.capability_apis.path IS
'Logical API route used for interface discovery. Runtime routing and execution remain outside the database.';


COMMENT ON COLUMN raamaesha.capability_apis.status IS
'Lifecycle state of the API interface version.';


COMMENT ON COLUMN raamaesha.capability_apis.permission_id IS
'Optional reference to the existing enterprise permission required to access the API.';


COMMENT ON COLUMN raamaesha.capability_apis.request_schema IS
'Machine-readable non-secret description of the API request structure.';


COMMENT ON COLUMN raamaesha.capability_apis.response_schema IS
'Machine-readable non-secret description of the API response structure.';


COMMENT ON COLUMN raamaesha.capability_apis.metadata IS
'Extensible non-secret API metadata for Tool Gateway and future runtime discovery. Plaintext secrets must not be stored here.';


COMMENT ON COLUMN raamaesha.capability_apis.created_at IS
'Timestamp when the API definition was created.';


COMMENT ON COLUMN raamaesha.capability_apis.updated_at IS
'Timestamp when the API definition was most recently updated.';


COMMENT ON COLUMN raamaesha.capability_apis.created_by IS
'Actor responsible for creating the API definition when known.';


COMMENT ON COLUMN raamaesha.capability_apis.updated_by IS
'Actor responsible for the most recent API definition update when known.';


COMMENT ON COLUMN raamaesha.capability_apis.deleted_at IS
'Soft deletion timestamp. NULL indicates that the API definition has not been soft deleted.';


-- =============================================================================
-- Capability API Indexes
-- =============================================================================

CREATE INDEX idx_capability_apis_capability
    ON raamaesha.capability_apis (capability_id);


CREATE INDEX idx_capability_apis_code
    ON raamaesha.capability_apis (code);


CREATE INDEX idx_capability_apis_status
    ON raamaesha.capability_apis (status);


CREATE INDEX idx_capability_apis_permission
    ON raamaesha.capability_apis (permission_id);


CREATE INDEX idx_capability_apis_deleted_at
    ON raamaesha.capability_apis (deleted_at);


CREATE INDEX idx_capability_apis_version
    ON raamaesha.capability_apis
    (
        capability_id,
        code,
        version DESC
    );


-- =============================================================================
-- Active Capability API Discovery
-- =============================================================================

CREATE INDEX idx_capability_apis_active_discovery
    ON raamaesha.capability_apis
    (
        capability_id,
        code,
        version DESC
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Production Integrity: One Active API Version
-- =============================================================================

CREATE UNIQUE INDEX ux_capability_apis_one_active
    ON raamaesha.capability_apis
    (
        capability_id,
        code
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Audit Trigger
-- =============================================================================

CREATE TRIGGER trg_capability_apis_set_updated_at
BEFORE UPDATE
ON raamaesha.capability_apis
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Capability Events
-- =============================================================================
--
-- Represents one version of an event interface associated with a reusable
-- platform capability.
--
-- The database stores event identity, discovery metadata, and authorization
-- references only.
--
-- Event publication, subscription, delivery, retries, queues, and processing
-- remain outside the database layer.
-- =============================================================================

CREATE TABLE raamaesha.capability_events
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    capability_id
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

    version
        INTEGER
        NOT NULL
        DEFAULT 1,

    direction
        public.capability_event_direction
        NOT NULL,

    status
        public.capability_event_status
        NOT NULL
        DEFAULT 'draft',

    permission_id
        UUID,

    payload_schema
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

    CONSTRAINT pk_capability_events
        PRIMARY KEY (id),


    -- =========================================================================
    -- Capability Relationship
    -- =========================================================================

    CONSTRAINT fk_capability_events_capability
        FOREIGN KEY (capability_id)
        REFERENCES raamaesha.capabilities (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Permission Relationship
    -- =========================================================================

    CONSTRAINT fk_capability_events_permission
        FOREIGN KEY (permission_id)
        REFERENCES raamaesha.permissions (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- Audit Actor Relationships
    -- =========================================================================

    CONSTRAINT fk_capability_events_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    CONSTRAINT fk_capability_events_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,


    -- =========================================================================
    -- Event Identity
    -- =========================================================================

    CONSTRAINT uq_capability_events_capability_code_version
        UNIQUE (capability_id, code, version),


    -- =========================================================================
    -- Event Code
    -- =========================================================================

    CONSTRAINT ck_capability_events_code
        CHECK (
            code ~ '^[a-z0-9]+(\.[a-z0-9_]+)*$'
        ),


    -- =========================================================================
    -- Event Name
    -- =========================================================================

    CONSTRAINT ck_capability_events_name_not_blank
        CHECK (
            length(trim(name)) > 0
        ),


    -- =========================================================================
    -- Event Version
    -- =========================================================================

    CONSTRAINT ck_capability_events_version_positive
        CHECK (
            version >= 1
        ),


    -- =========================================================================
    -- Payload Schema Integrity
    -- =========================================================================

    CONSTRAINT ck_capability_events_payload_schema_object
        CHECK (
            jsonb_typeof(payload_schema) = 'object'
        ),


    -- =========================================================================
    -- Metadata Integrity
    -- =========================================================================

    CONSTRAINT ck_capability_events_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )

);


-- =============================================================================
-- Capability Event Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.capability_events IS
'Registry of versioned event interfaces associated with reusable RaamaEsha OS capabilities.';


COMMENT ON COLUMN raamaesha.capability_events.id IS
'Globally unique identifier for the capability event version.';


COMMENT ON COLUMN raamaesha.capability_events.capability_id IS
'Capability definition that owns this event interface.';


COMMENT ON COLUMN raamaesha.capability_events.code IS
'Stable machine-readable event code within the owning capability.';


COMMENT ON COLUMN raamaesha.capability_events.name IS
'Human-readable name of the capability event.';


COMMENT ON COLUMN raamaesha.capability_events.description IS
'Optional human-readable description of the event and its intended purpose.';


COMMENT ON COLUMN raamaesha.capability_events.version IS
'Integer version of the event definition. A new version represents a materially changed externally discoverable event contract.';


COMMENT ON COLUMN raamaesha.capability_events.direction IS
'Whether the capability publishes or subscribes to the event.';


COMMENT ON COLUMN raamaesha.capability_events.status IS
'Lifecycle state of the event interface version.';


COMMENT ON COLUMN raamaesha.capability_events.permission_id IS
'Optional reference to the existing enterprise permission associated with the event interface.';


COMMENT ON COLUMN raamaesha.capability_events.payload_schema IS
'Machine-readable non-secret description of the event payload structure.';


COMMENT ON COLUMN raamaesha.capability_events.metadata IS
'Extensible non-secret event metadata for Tool Gateway and future runtime discovery. Plaintext secrets must not be stored here.';


COMMENT ON COLUMN raamaesha.capability_events.created_at IS
'Timestamp when the event definition was created.';


COMMENT ON COLUMN raamaesha.capability_events.updated_at IS
'Timestamp when the event definition was most recently updated.';


COMMENT ON COLUMN raamaesha.capability_events.created_by IS
'Actor responsible for creating the event definition when known.';


COMMENT ON COLUMN raamaesha.capability_events.updated_by IS
'Actor responsible for the most recent event definition update when known.';


COMMENT ON COLUMN raamaesha.capability_events.deleted_at IS
'Soft deletion timestamp. NULL indicates that the event definition has not been soft deleted.';


-- =============================================================================
-- Capability Event Indexes
-- =============================================================================

CREATE INDEX idx_capability_events_capability
    ON raamaesha.capability_events (capability_id);


CREATE INDEX idx_capability_events_code
    ON raamaesha.capability_events (code);


CREATE INDEX idx_capability_events_status
    ON raamaesha.capability_events (status);


CREATE INDEX idx_capability_events_direction
    ON raamaesha.capability_events (direction);


CREATE INDEX idx_capability_events_permission
    ON raamaesha.capability_events (permission_id);


CREATE INDEX idx_capability_events_deleted_at
    ON raamaesha.capability_events (deleted_at);


CREATE INDEX idx_capability_events_version
    ON raamaesha.capability_events
    (
        capability_id,
        code,
        version DESC
    );


-- =============================================================================
-- Active Capability Event Discovery
-- =============================================================================

CREATE INDEX idx_capability_events_active_discovery
    ON raamaesha.capability_events
    (
        capability_id,
        code,
        version DESC
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Production Integrity: One Active Event Version
-- =============================================================================

CREATE UNIQUE INDEX ux_capability_events_one_active
    ON raamaesha.capability_events
    (
        capability_id,
        code
    )
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Audit Trigger
-- =============================================================================

CREATE TRIGGER trg_capability_events_set_updated_at
BEFORE UPDATE
ON raamaesha.capability_events
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;