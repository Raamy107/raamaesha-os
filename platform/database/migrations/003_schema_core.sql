-- =============================================================================
-- RaamaEsha OS
-- Migration : 003_schema_core.sql
-- Module    : Platform Core
--
-- Purpose:
--   Creates the core platform tables.
--
-- Responsibilities:
--   - Create organizations table
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Organizations
-- =============================================================================

CREATE TABLE raamaesha.organizations
(
    id                      UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    code                    CITEXT
        NOT NULL,

    name                    TEXT
        NOT NULL,

    legal_name              TEXT,

    organization_type_code  TEXT
        NOT NULL,

    status_code             TEXT
        NOT NULL,

    primary_email           CITEXT,

    primary_phone           TEXT,

    website                 TEXT,

    timezone                TEXT
        NOT NULL
        DEFAULT 'Asia/Kolkata',

    currency_code           CHAR(3)
        NOT NULL
        DEFAULT 'INR',

    created_at              TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at              TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by              UUID,

    updated_by              UUID,

    deleted_at              TIMESTAMPTZ,

    CONSTRAINT pk_organizations
        PRIMARY KEY (id),

    CONSTRAINT uq_organizations_code
        UNIQUE (code),

    CONSTRAINT ck_organizations_currency_code
        CHECK (currency_code = UPPER(currency_code))
);

-- =============================================================================
-- Additional Constraints
-- =============================================================================

ALTER TABLE raamaesha.organizations
    ADD CONSTRAINT ck_organizations_code_not_blank
        CHECK (length(trim(code)) > 0),

    ADD CONSTRAINT ck_organizations_name_not_blank
        CHECK (length(trim(name)) > 0);

-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.organizations IS
'Represents a tenant organization within the RaamaEsha OS platform.';

COMMENT ON COLUMN raamaesha.organizations.id IS
'Globally unique identifier for the organization.';

COMMENT ON COLUMN raamaesha.organizations.code IS
'Unique immutable business code used for integrations and references.';

COMMENT ON COLUMN raamaesha.organizations.name IS
'Display name of the organization.';

COMMENT ON COLUMN raamaesha.organizations.legal_name IS
'Registered legal name of the organization.';

COMMENT ON COLUMN raamaesha.organizations.organization_type_code IS
'Business classification code.';

COMMENT ON COLUMN raamaesha.organizations.status_code IS
'Current operational status of the organization.';

COMMENT ON COLUMN raamaesha.organizations.primary_email IS
'Primary contact email address.';

COMMENT ON COLUMN raamaesha.organizations.primary_phone IS
'Primary contact phone number.';

COMMENT ON COLUMN raamaesha.organizations.website IS
'Official website URL.';

COMMENT ON COLUMN raamaesha.organizations.timezone IS
'Default time zone for the organization.';

COMMENT ON COLUMN raamaesha.organizations.currency_code IS
'Default ISO 4217 currency code.';

COMMENT ON COLUMN raamaesha.organizations.created_at IS
'Timestamp when the organization record was created.';

COMMENT ON COLUMN raamaesha.organizations.updated_at IS
'Timestamp when the organization record was last updated.';

COMMENT ON COLUMN raamaesha.organizations.created_by IS
'User who created the organization record.';

COMMENT ON COLUMN raamaesha.organizations.updated_by IS
'User who last updated the organization record.';

COMMENT ON COLUMN raamaesha.organizations.deleted_at IS
'Soft deletion timestamp. NULL indicates an active record.';

-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_organizations_name
    ON raamaesha.organizations (name);

CREATE INDEX idx_organizations_status_code
    ON raamaesha.organizations (status_code);

CREATE INDEX idx_organizations_deleted_at
    ON raamaesha.organizations (deleted_at);

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;