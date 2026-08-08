-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 014_reference_countries.sql
-- Module    : Reference Data
--
-- Purpose:
--   Seeds the enterprise country master data.
--
-- Responsibilities:
--   - Insert standard country reference data
--   - Maintain idempotent execution
--
-- Dependencies:
--   - 004_schema_business.sql
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Countries
-- =============================================================================

INSERT INTO raamaesha.countries
(
    iso2_code,
    iso3_code,
    numeric_code,
    name,
    official_name,
    phone_code,
    currency_code,
    timezone,
    is_active
)
VALUES

(
    'IN',
    'IND',
    '356',
    'India',
    'Republic of India',
    '+91',
    'INR',
    'Asia/Kolkata',
    TRUE
),

(
    'US',
    'USA',
    '840',
    'United States',
    'United States of America',
    '+1',
    'USD',
    'America/New_York',
    TRUE
),

(
    'GB',
    'GBR',
    '826',
    'United Kingdom',
    'United Kingdom of Great Britain and Northern Ireland',
    '+44',
    'GBP',
    'Europe/London',
    TRUE
),

(
    'AE',
    'ARE',
    '784',
    'United Arab Emirates',
    'United Arab Emirates',
    '+971',
    'AED',
    'Asia/Dubai',
    TRUE
),

(
    'SG',
    'SGP',
    '702',
    'Singapore',
    'Republic of Singapore',
    '+65',
    'SGD',
    'Asia/Singapore',
    TRUE
),

(
    'AU',
    'AUS',
    '036',
    'Australia',
    'Commonwealth of Australia',
    '+61',
    'AUD',
    'Australia/Sydney',
    TRUE
),

(
    'CA',
    'CAN',
    '124',
    'Canada',
    'Canada',
    '+1',
    'CAD',
    'America/Toronto',
    TRUE
),

(
    'DE',
    'DEU',
    '276',
    'Germany',
    'Federal Republic of Germany',
    '+49',
    'EUR',
    'Europe/Berlin',
    TRUE
),

(
    'JP',
    'JPN',
    '392',
    'Japan',
    'Japan',
    '+81',
    'JPY',
    'Asia/Tokyo',
    TRUE
),

(
    'FR',
    'FRA',
    '250',
    'France',
    'French Republic',
    '+33',
    'EUR',
    'Europe/Paris',
    TRUE
)

ON CONFLICT (iso2_code)
DO UPDATE
SET
    iso3_code      = EXCLUDED.iso3_code,
    numeric_code   = EXCLUDED.numeric_code,
    name           = EXCLUDED.name,
    official_name  = EXCLUDED.official_name,
    phone_code     = EXCLUDED.phone_code,
    currency_code  = EXCLUDED.currency_code,
    timezone       = EXCLUDED.timezone,
    is_active      = EXCLUDED.is_active,
    updated_at     = CURRENT_TIMESTAMP;

COMMIT;