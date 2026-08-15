-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 018_integration_platform.sql
-- Module    : Integration Platform
--
-- Purpose:
--   Creates the reusable enterprise integration foundation for RaamaEsha OS.
--
-- Responsibilities:
--   - Global integration provider catalog
--   - Organization-owned integrations
--   - Integration connection configuration
--   - Webhook endpoint registration
--   - Integration lifecycle management
--   - Provider-independent extensibility
--   - Audit and soft-delete support
--
-- Architecture:
--
--   Integration Providers
--          |
--          v
--   Organization Integrations
--          |
--          v
--   Integration Connections
--          |
--          +---- Webhook Endpoints
--
-- Design Principles:
--   - Provider agnostic
--   - Multi-tenant
--   - Extensible without schema redesign
--   - No provider-specific business logic
--   - Secrets are represented by references, not plaintext values
--   - Soft deletion supported
--   - Reusable audit infrastructure
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
-- ENUM : Integration Status
-- =============================================================================

CREATE TYPE public.integration_status AS ENUM
(
    'pending',
    'active',
    'suspended',
    'disabled',
    'error'
);

COMMENT ON TYPE public.integration_status IS
'Lifecycle state of an organization integration.';


-- =============================================================================
-- ENUM : Integration Connection Type
-- =============================================================================

CREATE TYPE public.integration_connection_type AS ENUM
(
    'api',
    'oauth2',
    'oidc',
    'saml',
    'webhook',
    'service_account',
    'custom'
);

COMMENT ON TYPE public.integration_connection_type IS
'Supported connection mechanisms for external integrations.';


-- =============================================================================
-- ENUM : Webhook Direction
-- =============================================================================

CREATE TYPE public.webhook_direction AS ENUM
(
    'inbound',
    'outbound'
);

COMMENT ON TYPE public.webhook_direction IS
'Direction of webhook communication relative to RaamaEsha OS.';


-- =============================================================================
-- Integration Providers
-- =============================================================================
--
-- Global provider catalog.
--
-- Examples:
--   razorpay
--   whatsapp
--   google
--   microsoft
--   slack
--   zoho
--
-- Provider-specific configuration belongs in metadata rather than requiring
-- a new database table for every provider.
-- =============================================================================

CREATE TABLE raamaesha.integration_providers
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

    provider_type
        TEXT
        NOT NULL,

    documentation_url
        TEXT,

    metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    is_system
        BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    is_active
        BOOLEAN
        NOT NULL
        DEFAULT TRUE,

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


    CONSTRAINT pk_integration_providers
        PRIMARY KEY (id),

    CONSTRAINT uq_integration_providers_code
        UNIQUE (code),

    CONSTRAINT ck_integration_providers_code_not_blank
        CHECK (length(trim(code::TEXT)) > 0),

    CONSTRAINT ck_integration_providers_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_integration_providers_provider_type_not_blank
        CHECK (length(trim(provider_type)) > 0),

    CONSTRAINT ck_integration_providers_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);


-- =============================================================================
-- Integration Provider Foreign Keys
-- =============================================================================

ALTER TABLE raamaesha.integration_providers
    ADD CONSTRAINT fk_integration_providers_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    ADD CONSTRAINT fk_integration_providers_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL;


-- =============================================================================
-- Integration Provider Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.integration_providers IS
'Global catalog of external systems and service providers supported by the integration platform.';

COMMENT ON COLUMN raamaesha.integration_providers.id IS
'Globally unique identifier for the integration provider.';

COMMENT ON COLUMN raamaesha.integration_providers.code IS
'Stable provider code used by platform integrations and APIs.';

COMMENT ON COLUMN raamaesha.integration_providers.name IS
'Human-readable provider name.';

COMMENT ON COLUMN raamaesha.integration_providers.description IS
'Description of the external provider.';

COMMENT ON COLUMN raamaesha.integration_providers.provider_type IS
'Provider classification used for extensibility and discovery.';

COMMENT ON COLUMN raamaesha.integration_providers.documentation_url IS
'Optional official documentation URL for the provider.';

COMMENT ON COLUMN raamaesha.integration_providers.metadata IS
'Extensible provider-specific metadata that does not belong in fixed columns.';

COMMENT ON COLUMN raamaesha.integration_providers.is_system IS
'Indicates whether the provider is a protected system-level provider.';

COMMENT ON COLUMN raamaesha.integration_providers.is_active IS
'Indicates whether the provider is available for new integrations.';

COMMENT ON COLUMN raamaesha.integration_providers.deleted_at IS
'Soft deletion timestamp. NULL indicates that the provider has not been soft deleted.';


-- =============================================================================
-- Integration Provider Indexes
-- =============================================================================

CREATE INDEX idx_integration_providers_name
    ON raamaesha.integration_providers (name);

CREATE INDEX idx_integration_providers_type
    ON raamaesha.integration_providers (provider_type);

CREATE INDEX idx_integration_providers_active
    ON raamaesha.integration_providers (is_active);

CREATE INDEX idx_integration_providers_deleted_at
    ON raamaesha.integration_providers (deleted_at);


-- =============================================================================
-- Organization Integrations
-- =============================================================================
--
-- Represents an organization's logical integration with an external provider.
--
-- One organization can have multiple integrations with the same provider.
-- This is intentional because an organization may have:
--   - production and sandbox connections
--   - multiple accounts
--   - multiple business units
--   - multiple regional accounts
-- =============================================================================

CREATE TABLE raamaesha.integrations
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id
        UUID
        NOT NULL,

    provider_id
        UUID
        NOT NULL,

    code
        TEXT
        NOT NULL,

    name
        TEXT
        NOT NULL,

    environment
        TEXT
        NOT NULL
        DEFAULT 'production',

    status
        public.integration_status
        NOT NULL
        DEFAULT 'pending',

    description
        TEXT,

    configuration
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    last_connected_at
        TIMESTAMPTZ,

    last_error_at
        TIMESTAMPTZ,

    last_error_message
        TEXT,

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


    CONSTRAINT pk_integrations
        PRIMARY KEY (id),

    CONSTRAINT uq_integrations_organization_code
        UNIQUE (organization_id, code),

    CONSTRAINT fk_integrations_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_integrations_provider
        FOREIGN KEY (provider_id)
        REFERENCES raamaesha.integration_providers (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_integrations_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT fk_integrations_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT ck_integrations_code_not_blank
        CHECK (length(trim(code)) > 0),

    CONSTRAINT ck_integrations_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_integrations_environment_not_blank
        CHECK (length(trim(environment)) > 0),

    CONSTRAINT ck_integrations_configuration_object
        CHECK (jsonb_typeof(configuration) = 'object'),

    CONSTRAINT ck_integrations_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object'),

    CONSTRAINT ck_integrations_last_error_message_not_blank
        CHECK (
            last_error_message IS NULL
            OR length(trim(last_error_message)) > 0
        )
);


-- =============================================================================
-- Integration Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.integrations IS
'Organization-owned logical integrations connecting RaamaEsha OS to external providers.';

COMMENT ON COLUMN raamaesha.integrations.id IS
'Globally unique identifier for the integration.';

COMMENT ON COLUMN raamaesha.integrations.organization_id IS
'Organization that owns the integration.';

COMMENT ON COLUMN raamaesha.integrations.provider_id IS
'External provider represented by the integration.';

COMMENT ON COLUMN raamaesha.integrations.code IS
'Organization-specific stable integration code.';

COMMENT ON COLUMN raamaesha.integrations.name IS
'Human-readable integration name.';

COMMENT ON COLUMN raamaesha.integrations.environment IS
'Execution environment such as production, sandbox, staging, or development.';

COMMENT ON COLUMN raamaesha.integrations.status IS
'Current lifecycle status of the integration.';

COMMENT ON COLUMN raamaesha.integrations.configuration IS
'Non-secret integration configuration stored as extensible JSONB. Secrets must not be stored here.';

COMMENT ON COLUMN raamaesha.integrations.metadata IS
'Extensible integration metadata for provider-specific or future platform requirements.';

COMMENT ON COLUMN raamaesha.integrations.last_connected_at IS
'Timestamp of the most recent successful connection.';

COMMENT ON COLUMN raamaesha.integrations.last_error_at IS
'Timestamp of the most recent integration error.';

COMMENT ON COLUMN raamaesha.integrations.last_error_message IS
'Last non-secret diagnostic error message associated with the integration.';

COMMENT ON COLUMN raamaesha.integrations.deleted_at IS
'Soft deletion timestamp. NULL indicates that the integration has not been soft deleted.';


-- =============================================================================
-- Integration Indexes
-- =============================================================================

CREATE INDEX idx_integrations_organization
    ON raamaesha.integrations (organization_id);

CREATE INDEX idx_integrations_provider
    ON raamaesha.integrations (provider_id);

CREATE INDEX idx_integrations_status
    ON raamaesha.integrations (status);

CREATE INDEX idx_integrations_environment
    ON raamaesha.integrations (environment);

CREATE INDEX idx_integrations_deleted_at
    ON raamaesha.integrations (deleted_at);


-- =============================================================================
-- Integration Connections
-- =============================================================================
--
-- Physical connection configuration for an integration.
--
-- Multiple connections are intentionally supported.
-- =============================================================================

CREATE TABLE raamaesha.integration_connections
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

    connection_type
        public.integration_connection_type
        NOT NULL,

    endpoint_url
        TEXT,

    credential_reference
        TEXT,

    configuration
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    is_primary
        BOOLEAN
        NOT NULL
        DEFAULT FALSE,

    is_active
        BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    last_verified_at
        TIMESTAMPTZ,

    last_error_at
        TIMESTAMPTZ,

    last_error_message
        TEXT,

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


    CONSTRAINT pk_integration_connections
        PRIMARY KEY (id),

    CONSTRAINT uq_integration_connections_integration_code
        UNIQUE (integration_id, code),

    CONSTRAINT uq_integration_connections_id_integration
        UNIQUE (id, integration_id),

    CONSTRAINT fk_integration_connections_integration
        FOREIGN KEY (integration_id)
        REFERENCES raamaesha.integrations (id)
        ON DELETE CASCADE,

    CONSTRAINT fk_integration_connections_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT fk_integration_connections_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT ck_integration_connections_code_not_blank
        CHECK (length(trim(code)) > 0),

    CONSTRAINT ck_integration_connections_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_integration_connections_endpoint_url_not_blank
        CHECK (
            endpoint_url IS NULL
            OR length(trim(endpoint_url)) > 0
        ),

    CONSTRAINT ck_integration_connections_credential_reference_not_blank
        CHECK (
            credential_reference IS NULL
            OR length(trim(credential_reference)) > 0
        ),

    CONSTRAINT ck_integration_connections_configuration_object
        CHECK (jsonb_typeof(configuration) = 'object'),

    CONSTRAINT ck_integration_connections_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object'),

    CONSTRAINT ck_integration_connections_last_error_message_not_blank
        CHECK (
            last_error_message IS NULL
            OR length(trim(last_error_message)) > 0
        )
);


-- =============================================================================
-- Integration Connection Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.integration_connections IS
'Physical connection definitions belonging to an organization integration.';

COMMENT ON COLUMN raamaesha.integration_connections.id IS
'Globally unique identifier for the connection.';

COMMENT ON COLUMN raamaesha.integration_connections.integration_id IS
'Logical integration that owns the connection.';

COMMENT ON COLUMN raamaesha.integration_connections.code IS
'Stable connection code within the parent integration.';

COMMENT ON COLUMN raamaesha.integration_connections.name IS
'Human-readable connection name.';

COMMENT ON COLUMN raamaesha.integration_connections.connection_type IS
'Authentication or communication mechanism used by the connection.';

COMMENT ON COLUMN raamaesha.integration_connections.endpoint_url IS
'Optional remote endpoint associated with the connection.';

COMMENT ON COLUMN raamaesha.integration_connections.credential_reference IS
'Reference to an external secret or credential store. Plaintext secrets must not be stored in this column.';

COMMENT ON COLUMN raamaesha.integration_connections.configuration IS
'Non-secret connection configuration stored as extensible JSONB.';

COMMENT ON COLUMN raamaesha.integration_connections.metadata IS
'Extensible connection metadata.';

COMMENT ON COLUMN raamaesha.integration_connections.is_primary IS
'Indicates whether the connection is designated as the primary connection.';

COMMENT ON COLUMN raamaesha.integration_connections.is_active IS
'Indicates whether the connection is currently available for use.';

COMMENT ON COLUMN raamaesha.integration_connections.last_verified_at IS
'Timestamp when the connection was most recently verified successfully.';

COMMENT ON COLUMN raamaesha.integration_connections.last_error_at IS
'Timestamp of the most recent connection error.';

COMMENT ON COLUMN raamaesha.integration_connections.last_error_message IS
'Last non-secret diagnostic error message associated with the connection.';

COMMENT ON COLUMN raamaesha.integration_connections.deleted_at IS
'Soft deletion timestamp. NULL indicates that the connection has not been soft deleted.';


-- =============================================================================
-- Integration Connection Indexes
-- =============================================================================

CREATE INDEX idx_integration_connections_integration
    ON raamaesha.integration_connections (integration_id);

CREATE INDEX idx_integration_connections_type
    ON raamaesha.integration_connections (connection_type);

CREATE INDEX idx_integration_connections_active
    ON raamaesha.integration_connections (is_active);

CREATE INDEX idx_integration_connections_primary
    ON raamaesha.integration_connections (integration_id, is_primary)
    WHERE is_primary = TRUE
      AND deleted_at IS NULL;

CREATE INDEX idx_integration_connections_deleted_at
    ON raamaesha.integration_connections (deleted_at);


-- =============================================================================
-- Webhook Endpoints
-- =============================================================================
--
-- Registers inbound and outbound webhook endpoints.
--
-- Endpoint-specific secrets must be stored through a secure credential
-- mechanism and referenced through credential_reference.
-- =============================================================================

CREATE TABLE raamaesha.webhook_endpoints
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

    code
        TEXT
        NOT NULL,

    name
        TEXT
        NOT NULL,

    direction
        public.webhook_direction
        NOT NULL,

    endpoint_path
        TEXT
        NOT NULL,

    event_filter
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    credential_reference
        TEXT,

    metadata
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    is_active
        BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    last_received_at
        TIMESTAMPTZ,

    last_sent_at
        TIMESTAMPTZ,

    last_error_at
        TIMESTAMPTZ,

    last_error_message
        TEXT,

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


    CONSTRAINT pk_webhook_endpoints
        PRIMARY KEY (id),

    CONSTRAINT uq_webhook_endpoints_integration_code
        UNIQUE (integration_id, code),

    CONSTRAINT fk_webhook_endpoints_integration
        FOREIGN KEY (integration_id)
        REFERENCES raamaesha.integrations (id)
        ON DELETE CASCADE,
    CONSTRAINT fk_webhook_endpoints_connection
    FOREIGN KEY (connection_id, integration_id)
    REFERENCES raamaesha.integration_connections (id, integration_id)
    ON DELETE SET NULL,
    
    CONSTRAINT fk_webhook_endpoints_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT fk_webhook_endpoints_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors (id)
        ON DELETE SET NULL,

    CONSTRAINT ck_webhook_endpoints_code_not_blank
        CHECK (length(trim(code)) > 0),

    CONSTRAINT ck_webhook_endpoints_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_webhook_endpoints_path_not_blank
        CHECK (length(trim(endpoint_path)) > 0),

    CONSTRAINT ck_webhook_endpoints_event_filter_object
        CHECK (jsonb_typeof(event_filter) = 'object'),

    CONSTRAINT ck_webhook_endpoints_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object'),

    CONSTRAINT ck_webhook_endpoints_credential_reference_not_blank
        CHECK (
            credential_reference IS NULL
            OR length(trim(credential_reference)) > 0
        ),

    CONSTRAINT ck_webhook_endpoints_last_error_message_not_blank
        CHECK (
            last_error_message IS NULL
            OR length(trim(last_error_message)) > 0
        )
);


-- =============================================================================
-- Webhook Endpoint Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.webhook_endpoints IS
'Reusable registry of inbound and outbound webhook endpoints associated with integrations.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.id IS
'Globally unique identifier for the webhook endpoint.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.integration_id IS
'Integration that owns the webhook endpoint.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.connection_id IS
'Optional connection associated with the webhook endpoint.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.code IS
'Stable webhook endpoint code within the integration.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.name IS
'Human-readable webhook endpoint name.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.direction IS
'Indicates whether the webhook is inbound to or outbound from RaamaEsha OS.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.endpoint_path IS
'Logical webhook endpoint path or route.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.event_filter IS
'Extensible JSONB event filtering configuration.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.credential_reference IS
'Reference to a secure secret or credential store. Plaintext webhook secrets must not be stored here.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.metadata IS
'Extensible webhook metadata.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.is_active IS
'Indicates whether the webhook endpoint is active.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.last_received_at IS
'Timestamp when an inbound webhook was most recently received.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.last_sent_at IS
'Timestamp when an outbound webhook was most recently sent.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.last_error_at IS
'Timestamp of the most recent webhook error.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.last_error_message IS
'Last non-secret diagnostic webhook error message.';

COMMENT ON COLUMN raamaesha.webhook_endpoints.deleted_at IS
'Soft deletion timestamp. NULL indicates that the webhook endpoint has not been soft deleted.';


-- =============================================================================
-- Webhook Endpoint Indexes
-- =============================================================================

CREATE INDEX idx_webhook_endpoints_integration
    ON raamaesha.webhook_endpoints (integration_id);

CREATE INDEX idx_webhook_endpoints_connection
    ON raamaesha.webhook_endpoints (connection_id);

CREATE INDEX idx_webhook_endpoints_direction
    ON raamaesha.webhook_endpoints (direction);

CREATE INDEX idx_webhook_endpoints_active
    ON raamaesha.webhook_endpoints (is_active);

CREATE INDEX idx_webhook_endpoints_deleted_at
    ON raamaesha.webhook_endpoints (deleted_at);


-- =============================================================================
-- Audit Triggers
-- =============================================================================

CREATE TRIGGER trg_integration_providers_set_updated_at
BEFORE UPDATE
ON raamaesha.integration_providers
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


CREATE TRIGGER trg_integrations_set_updated_at
BEFORE UPDATE
ON raamaesha.integrations
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


CREATE TRIGGER trg_integration_connections_set_updated_at
BEFORE UPDATE
ON raamaesha.integration_connections
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


CREATE TRIGGER trg_webhook_endpoints_set_updated_at
BEFORE UPDATE
ON raamaesha.webhook_endpoints
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;
-- =============================================================================
-- Production Integrity: One Primary Connection Per Integration
-- =============================================================================

CREATE UNIQUE INDEX ux_integration_connections_one_primary
    ON raamaesha.integration_connections (integration_id)
    WHERE is_primary = TRUE
      AND deleted_at IS NULL;

