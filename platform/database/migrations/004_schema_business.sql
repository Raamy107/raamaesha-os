-- =============================================================================
-- RaamaEsha OS
-- Migration : 004_schema_business.sql
-- Module    : Business Foundation
--
-- Purpose:
--   Creates foundational business master tables shared across all modules.
--
-- Responsibilities:
--   - Countries
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Countries
-- =============================================================================

CREATE TABLE raamaesha.countries
(
    id                  UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    iso2_code           CHAR(2)
        NOT NULL,

    iso3_code           CHAR(3)
        NOT NULL,

    numeric_code        CHAR(3),

    name                TEXT
        NOT NULL,

    official_name       TEXT,

    phone_code          TEXT,

    currency_code       CHAR(3),

    timezone            TEXT,

    is_active           BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    created_at          TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at          TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by          UUID,

    updated_by          UUID,

    deleted_at          TIMESTAMPTZ,

    CONSTRAINT pk_countries
        PRIMARY KEY (id),

    CONSTRAINT uq_countries_iso2
        UNIQUE (iso2_code),

    CONSTRAINT uq_countries_iso3
        UNIQUE (iso3_code),

    CONSTRAINT ck_countries_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_countries_iso2_upper
        CHECK (iso2_code = UPPER(iso2_code)),

    CONSTRAINT ck_countries_iso3_upper
        CHECK (iso3_code = UPPER(iso3_code))
);

-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.countries IS
'Master list of countries supported by the RaamaEsha OS platform.';

COMMENT ON COLUMN raamaesha.countries.id IS
'Globally unique identifier for the country.';

COMMENT ON COLUMN raamaesha.countries.iso2_code IS
'ISO 3166-1 alpha-2 country code.';

COMMENT ON COLUMN raamaesha.countries.iso3_code IS
'ISO 3166-1 alpha-3 country code.';

COMMENT ON COLUMN raamaesha.countries.numeric_code IS
'ISO 3166-1 numeric country code.';

COMMENT ON COLUMN raamaesha.countries.name IS
'Common English name of the country.';

COMMENT ON COLUMN raamaesha.countries.official_name IS
'Official constitutional name of the country.';

COMMENT ON COLUMN raamaesha.countries.phone_code IS
'International telephone dialing code.';

COMMENT ON COLUMN raamaesha.countries.currency_code IS
'ISO 4217 currency code.';

COMMENT ON COLUMN raamaesha.countries.timezone IS
'Default IANA time zone for the country.';

COMMENT ON COLUMN raamaesha.countries.is_active IS
'Indicates whether the country is active for business operations.';

COMMENT ON COLUMN raamaesha.countries.created_at IS
'Timestamp when the country record was created.';

COMMENT ON COLUMN raamaesha.countries.updated_at IS
'Timestamp when the country record was last updated.';

COMMENT ON COLUMN raamaesha.countries.created_by IS
'User who created the country record.';

COMMENT ON COLUMN raamaesha.countries.updated_by IS
'User who last updated the country record.';

COMMENT ON COLUMN raamaesha.countries.deleted_at IS
'Soft deletion timestamp. NULL indicates an active record.';

-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_countries_name
    ON raamaesha.countries (name);

CREATE INDEX idx_countries_active
    ON raamaesha.countries (is_active);

CREATE INDEX idx_countries_currency_code
    ON raamaesha.countries (currency_code);

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;