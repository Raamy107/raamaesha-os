-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 017_reference_branches.sql
-- Module    : Business Foundation
--
-- Purpose:
--   Creates the organization-owned branch master.
--
-- Responsibilities:
--   - Associate branches with organizations
--   - Associate branches with the geographic city master
--   - Maintain organization-specific branch identity
--   - Provide branch contact and address information
--   - Support branch-level timezone and currency settings
--   - Reuse platform audit infrastructure
--
-- Architecture:
--   Organizations -> Branches -> Cities -> Regions -> Countries
--
-- Dependencies:
--   - 003_schema_core.sql
--   - 004_schema_business.sql
--   - 013_audit_infrastructure.sql
--   - 016_reference_cities.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Branches
-- =============================================================================

CREATE TABLE raamaesha.branches
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id
        UUID
        NOT NULL,

    city_id
        UUID
        NOT NULL,

    code
        TEXT
        NOT NULL,

    name
        TEXT
        NOT NULL,

    legal_name
        TEXT,

    branch_type
        TEXT,

    status_code
        TEXT
        NOT NULL,

    primary_email
        CITEXT,

    primary_phone
        TEXT,

    website
        TEXT,

    address_line_1
        TEXT,

    address_line_2
        TEXT,

    postal_code
        TEXT,

    timezone
        TEXT
        NOT NULL
        DEFAULT 'Asia/Kolkata',

    currency_code
        CHAR(3)
        NOT NULL
        DEFAULT 'INR',

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

    CONSTRAINT pk_branches
        PRIMARY KEY (id),


    -- =========================================================================
    -- Organization Relationship
    -- =========================================================================

    CONSTRAINT fk_branches_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations (id)
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Geographic Relationship
    -- =========================================================================

    CONSTRAINT fk_branches_city
        FOREIGN KEY (city_id)
        REFERENCES raamaesha.cities (id)
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Data Integrity
    -- =========================================================================

    CONSTRAINT ck_branches_code_not_blank
        CHECK (length(trim(code)) > 0),

    CONSTRAINT ck_branches_name_not_blank
        CHECK (length(trim(name)) > 0),

    CONSTRAINT ck_branches_legal_name_not_blank
        CHECK (
            legal_name IS NULL
            OR length(trim(legal_name)) > 0
        ),

    CONSTRAINT ck_branches_branch_type_not_blank
        CHECK (
            branch_type IS NULL
            OR length(trim(branch_type)) > 0
        ),

    CONSTRAINT ck_branches_status_code_not_blank
        CHECK (length(trim(status_code)) > 0),

    CONSTRAINT ck_branches_address_line_1_not_blank
        CHECK (
            address_line_1 IS NULL
            OR length(trim(address_line_1)) > 0
        ),

    CONSTRAINT ck_branches_address_line_2_not_blank
        CHECK (
            address_line_2 IS NULL
            OR length(trim(address_line_2)) > 0
        ),

    CONSTRAINT ck_branches_postal_code_not_blank
        CHECK (
            postal_code IS NULL
            OR length(trim(postal_code)) > 0
        ),

    CONSTRAINT ck_branches_currency_code_upper
        CHECK (currency_code = UPPER(currency_code))
);


-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.branches IS
'Organization-owned operating branch master. Each branch belongs to one organization and references a city from the global geographic hierarchy.';


COMMENT ON COLUMN raamaesha.branches.id IS
'Globally unique identifier for the branch.';


COMMENT ON COLUMN raamaesha.branches.organization_id IS
'Organization that owns and operates the branch.';


COMMENT ON COLUMN raamaesha.branches.city_id IS
'City in which the branch is geographically located.';


COMMENT ON COLUMN raamaesha.branches.code IS
'Organization-specific business code used to identify the branch.';


COMMENT ON COLUMN raamaesha.branches.name IS
'Display name of the branch.';


COMMENT ON COLUMN raamaesha.branches.legal_name IS
'Registered or legally recognized name of the branch where applicable.';


COMMENT ON COLUMN raamaesha.branches.branch_type IS
'Optional classification of the branch. A controlled taxonomy may be introduced later when required by the platform architecture.';


COMMENT ON COLUMN raamaesha.branches.status_code IS
'Operational status code of the branch.';


COMMENT ON COLUMN raamaesha.branches.primary_email IS
'Primary contact email address for the branch.';


COMMENT ON COLUMN raamaesha.branches.primary_phone IS
'Primary contact phone number for the branch.';


COMMENT ON COLUMN raamaesha.branches.website IS
'Official website associated with the branch, where applicable.';


COMMENT ON COLUMN raamaesha.branches.address_line_1 IS
'Primary physical address line of the branch.';


COMMENT ON COLUMN raamaesha.branches.address_line_2 IS
'Secondary physical address line of the branch.';


COMMENT ON COLUMN raamaesha.branches.postal_code IS
'Postal or ZIP code associated with the branch address.';


COMMENT ON COLUMN raamaesha.branches.timezone IS
'Operational time zone used by the branch.';


COMMENT ON COLUMN raamaesha.branches.currency_code IS
'Default ISO 4217 currency code used by the branch.';


COMMENT ON COLUMN raamaesha.branches.created_at IS
'Timestamp when the branch record was created.';


COMMENT ON COLUMN raamaesha.branches.updated_at IS
'Timestamp when the branch record was last updated.';


COMMENT ON COLUMN raamaesha.branches.created_by IS
'User who created the branch record.';


COMMENT ON COLUMN raamaesha.branches.updated_by IS
'User who last updated the branch record.';


COMMENT ON COLUMN raamaesha.branches.deleted_at IS
'Soft deletion timestamp. NULL indicates that the branch has not been soft deleted.';


-- =============================================================================
-- Organization-Specific Branch Identity
-- =============================================================================

CREATE UNIQUE INDEX uq_branches_organization_code
ON raamaesha.branches
(
    organization_id,
    code
);


-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_branches_organization_id
ON raamaesha.branches
(
    organization_id
);


CREATE INDEX idx_branches_city_id
ON raamaesha.branches
(
    city_id
);


CREATE INDEX idx_branches_name
ON raamaesha.branches
(
    name
);


CREATE INDEX idx_branches_status_code
ON raamaesha.branches
(
    status_code
);


-- =============================================================================
-- Audit Trigger
-- =============================================================================

CREATE TRIGGER trg_branches_set_updated_at
BEFORE UPDATE
ON raamaesha.branches
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;