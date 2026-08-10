-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 016_reference_cities.sql
-- Module    : Reference Data
--
-- Purpose:
--   Creates the global city/locality master beneath the administrative
--   region master.
--
-- Responsibilities:
--   - Create reusable city/locality reference data
--   - Maintain the Country -> Region -> City hierarchy
--   - Provide appropriate integrity constraints and indexes
--   - Reuse the platform audit timestamp infrastructure
--
-- Dependencies:
--   - 004_schema_business.sql
--   - 013_audit_infrastructure.sql
--   - 015_reference_regions.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Cities
-- =============================================================================

CREATE TABLE raamaesha.cities
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    region_id
        UUID
        NOT NULL,

    code
        TEXT,

    name
        TEXT
        NOT NULL,

    official_name
        TEXT,

    city_type
        TEXT,

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

    CONSTRAINT pk_cities
        PRIMARY KEY (id),

    CONSTRAINT fk_cities_region
        FOREIGN KEY (region_id)
        REFERENCES raamaesha.regions (id)
        ON DELETE RESTRICT,

    CONSTRAINT ck_cities_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_cities_code_not_blank
        CHECK (
            code IS NULL
            OR length(trim(code)) > 0
        ),

    CONSTRAINT ck_cities_official_name_not_blank
        CHECK (
            official_name IS NULL
            OR length(trim(official_name)) > 0
        )
);


-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.cities IS
'Global reusable city and locality master beneath the administrative region hierarchy.';


COMMENT ON COLUMN raamaesha.cities.id IS
'Globally unique identifier for the city or locality.';


COMMENT ON COLUMN raamaesha.cities.region_id IS
'Reference to the administrative region containing the city or locality. Country is derived through the region hierarchy.';


COMMENT ON COLUMN raamaesha.cities.code IS
'Optional administrative or locally defined city or locality code.';


COMMENT ON COLUMN raamaesha.cities.name IS
'Common display name of the city or locality.';


COMMENT ON COLUMN raamaesha.cities.official_name IS
'Official name of the city or locality where applicable.';


COMMENT ON COLUMN raamaesha.cities.city_type IS
'Optional classification of the city or locality. A controlled taxonomy may be introduced later when required by the platform architecture.';


COMMENT ON COLUMN raamaesha.cities.is_active IS
'Indicates whether the city or locality is currently active for platform reference use.';


COMMENT ON COLUMN raamaesha.cities.created_at IS
'Timestamp when the city or locality record was created.';


COMMENT ON COLUMN raamaesha.cities.updated_at IS
'Timestamp when the city or locality record was last updated.';


COMMENT ON COLUMN raamaesha.cities.created_by IS
'User who created the city or locality record.';


COMMENT ON COLUMN raamaesha.cities.updated_by IS
'User who last updated the city or locality record.';


COMMENT ON COLUMN raamaesha.cities.deleted_at IS
'Soft deletion timestamp. NULL indicates that the record has not been soft deleted.';


-- =============================================================================
-- Natural Identity
-- =============================================================================

CREATE UNIQUE INDEX uq_cities_region_name
ON raamaesha.cities
(
    region_id,
    name
);


CREATE UNIQUE INDEX uq_cities_region_code
ON raamaesha.cities
(
    region_id,
    code
)
WHERE code IS NOT NULL;


-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_cities_region_id
ON raamaesha.cities (region_id);


CREATE INDEX idx_cities_name
ON raamaesha.cities (name);


CREATE INDEX idx_cities_active
ON raamaesha.cities (is_active);


-- =============================================================================
-- Audit Trigger
-- =============================================================================

CREATE TRIGGER trg_cities_set_updated_at
BEFORE UPDATE
ON raamaesha.cities
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;