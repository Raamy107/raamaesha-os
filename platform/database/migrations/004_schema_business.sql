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
--   - States
--   - Cities
--   - Branches
--   - Departments
--   - Business Units
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;-- =============================================================================
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

    CONSTRAINT pk_countries
        PRIMARY KEY (id),

    CONSTRAINT uq_countries_iso2
        UNIQUE (iso2_code),

    CONSTRAINT uq_countries_iso3
        UNIQUE (iso3_code)
);
-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.countries IS
'Master list of countries supported by the RaamaEsha OS platform.';

COMMENT ON COLUMN raamaesha.countries.iso2_code IS
'ISO 3166-1 alpha-2 country code.';

COMMENT ON COLUMN raamaesha.countries.iso3_code IS
'ISO 3166-1 alpha-3 country code.';

COMMENT ON COLUMN raamaesha.countries.numeric_code IS
'ISO 3166-1 numeric country code.';
-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_countries_name
    ON raamaesha.countries (name);

CREATE INDEX idx_countries_active
    ON raamaesha.countries (is_active);


-- ============================================================================
-- Migration Complete
-- ============================================================================

COMMIT;