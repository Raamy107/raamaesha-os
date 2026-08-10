-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 015_reference_regions.sql
-- Module    : Reference Data
--
-- Purpose:
--   Creates the global administrative region master beneath the country master.
--
-- Responsibilities:
--   - Create the global region reference structure
--   - Establish the country-to-region relationship
--   - Support international administrative terminology
--   - Provide audit and soft-delete infrastructure
--
-- Dependencies:
--   - 004_schema_business.sql
--   - 013_audit_infrastructure.sql
--   - 014_reference_countries.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Regions
-- =============================================================================

CREATE TABLE raamaesha.regions
(
    id                  UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    country_id          UUID
        NOT NULL,

    code                TEXT,

    name                TEXT
        NOT NULL,

    official_name       TEXT,

    region_type         TEXT
        NOT NULL,

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

    CONSTRAINT pk_regions
        PRIMARY KEY (id),

    CONSTRAINT fk_regions_country
        FOREIGN KEY (country_id)
        REFERENCES raamaesha.countries (id),

    CONSTRAINT uq_regions_country_name
        UNIQUE (country_id, name),

    CONSTRAINT ck_regions_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_regions_region_type_not_blank
        CHECK (length(trim(region_type)) > 0)
);


-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.regions IS
'Global master list of first-level administrative regions associated with countries.';

COMMENT ON COLUMN raamaesha.regions.id IS
'Globally unique identifier for the administrative region.';

COMMENT ON COLUMN raamaesha.regions.country_id IS
'Country to which the administrative region belongs.';

COMMENT ON COLUMN raamaesha.regions.code IS
'Optional administrative code assigned to the region within its country.';

COMMENT ON COLUMN raamaesha.regions.name IS
'Common display name of the administrative region.';

COMMENT ON COLUMN raamaesha.regions.official_name IS
'Official administrative name of the region, where applicable.';

COMMENT ON COLUMN raamaesha.regions.region_type IS
'Administrative classification of the region, such as state, province, territory, prefecture, or region.';

COMMENT ON COLUMN raamaesha.regions.is_active IS
'Indicates whether the region is active for business operations.';

COMMENT ON COLUMN raamaesha.regions.created_at IS
'Timestamp when the region record was created.';

COMMENT ON COLUMN raamaesha.regions.updated_at IS
'Timestamp when the region record was last updated.';

COMMENT ON COLUMN raamaesha.regions.created_by IS
'User who created the region record.';

COMMENT ON COLUMN raamaesha.regions.updated_by IS
'User who last updated the region record.';

COMMENT ON COLUMN raamaesha.regions.deleted_at IS
'Soft deletion timestamp. NULL indicates an active record.';


-- =============================================================================
-- Unique Administrative Code
-- =============================================================================

CREATE UNIQUE INDEX uq_regions_country_code
    ON raamaesha.regions (country_id, code)
    WHERE code IS NOT NULL;


-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_regions_country_id
    ON raamaesha.regions (country_id);

CREATE INDEX idx_regions_name
    ON raamaesha.regions (name);


-- =============================================================================
-- Audit Trigger
-- =============================================================================

CREATE TRIGGER trg_regions_set_updated_at
BEFORE UPDATE
ON raamaesha.regions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;