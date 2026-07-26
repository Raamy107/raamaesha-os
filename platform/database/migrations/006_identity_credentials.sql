-- =============================================================================
-- RaamaEsha OS
-- Migration : 006_identity_credentials.sql
-- Module    : Identity & Access Management
--
-- Purpose:
--   Creates the authentication credential foundation for global users.
--
-- Responsibilities:
--   - Identity credential types
--   - User authentication credentials
--   - Password metadata
--   - Credential verification
--   - Login security metadata
--
-- Dependencies:
--   001_extensions.sql
--   002_types.sql
--   003_schema_core.sql
--   004_schema_business.sql
--   005_identity_users.sql
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- ENUM : credential_type
-- =============================================================================

CREATE TYPE public.credential_type AS ENUM (
    'EMAIL',
    'PHONE',
    'USERNAME',
    'GOOGLE',
    'MICROSOFT',
    'APPLE',
    'GITHUB',
    'OIDC',
    'SAML',
    'PASSKEY',
    'SERVICE_ACCOUNT'
);

COMMENT ON TYPE public.credential_type IS
'Supported authentication credential types.';

-- =============================================================================
-- ENUM : credential_status
-- =============================================================================

CREATE TYPE public.credential_status AS ENUM (
    'PENDING_VERIFICATION',
    'ACTIVE',
    'LOCKED',
    'DISABLED',
    'EXPIRED',
    'COMPROMISED'
);

COMMENT ON TYPE public.credential_status IS
'Lifecycle state of an authentication credential.';

-- =============================================================================
-- ENUM : verification_method
-- =============================================================================

CREATE TYPE public.verification_method AS ENUM (
    'EMAIL_LINK',
    'EMAIL_OTP',
    'SMS_OTP',
    'TOTP',
    'AUTHENTICATOR_APP',
    'PASSKEY',
    'SECURITY_KEY',
    'ADMIN',
    'SSO',
    'SYSTEM'
);

COMMENT ON TYPE public.verification_method IS
'Method used to verify ownership of a credential.';

COMMIT;