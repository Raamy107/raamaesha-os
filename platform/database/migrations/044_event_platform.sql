-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 044_event_platform.sql
-- Module    : Event Platform
--
-- Purpose:
--   Creates the foundational immutable event occurrence store for the
--   RaamaEsha OS Event Platform.
--
-- Responsibilities:
--   - Immutable business event occurrences
--   - Organization / tenant association
--   - Actor association
--   - Stable event type identification
--   - Event occurrence timestamp
--   - Cross-operation correlation
--   - JSONB event payload
--
-- Design Boundary:
--   - capability_events remains the event interface / contract registry.
--   - This table stores actual event occurrences.
--   - Publication, subscription, delivery, retries, queues, and processing
--     remain outside the database foundation.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;


-- =============================================================================
-- Event Occurrences
-- =============================================================================
--
-- Represents one immutable occurrence of a business event within an
-- organization tenant.
--
-- This table is intentionally separate from capability_events:
--
--   capability_events = event definition / interface
--   events            = actual event occurrence
--
-- Event records are append-only. UPDATE and DELETE are explicitly rejected
-- by the database trigger defined below.
-- =============================================================================

CREATE TABLE raamaesha.events
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id
        UUID
        NOT NULL,

    actor_id
        UUID
        NOT NULL,

    event_type
        TEXT
        NOT NULL,

    occurred_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    correlation_id
        TEXT,

    payload
        JSONB
        NOT NULL
        DEFAULT '{}'::JSONB,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,


    -- =========================================================================
    -- Primary Key
    -- =========================================================================

    CONSTRAINT pk_events
        PRIMARY KEY (id),


    -- =========================================================================
    -- Organization / Tenant Relationship
    -- =========================================================================

    CONSTRAINT fk_events_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Actor Relationship
    -- =========================================================================

    CONSTRAINT fk_events_actor
        FOREIGN KEY (actor_id)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,


    -- =========================================================================
    -- Event Type Integrity
    -- =========================================================================

    CONSTRAINT ck_events_event_type_not_blank
        CHECK (
            length(trim(event_type)) > 0
        ),


    -- =========================================================================
    -- Correlation Integrity
    -- =========================================================================

    CONSTRAINT ck_events_correlation_id_not_blank
        CHECK (
            correlation_id IS NULL
            OR length(trim(correlation_id)) > 0
        ),


    -- =========================================================================
    -- Payload Integrity
    -- =========================================================================

    CONSTRAINT ck_events_payload_object
        CHECK (
            jsonb_typeof(payload) = 'object'
        )

);


-- =============================================================================
-- Event Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.events IS
'Immutable business event occurrences recorded by the RaamaEsha OS Event Platform.';


COMMENT ON COLUMN raamaesha.events.id IS
'Globally unique identifier for the immutable event occurrence.';


COMMENT ON COLUMN raamaesha.events.organization_id IS
'Tenant organization in whose business context the event occurred.';


COMMENT ON COLUMN raamaesha.events.actor_id IS
'Actor responsible for or associated with the business action that produced the event.';


COMMENT ON COLUMN raamaesha.events.event_type IS
'Stable machine-readable business event type identifying the kind of occurrence.';


COMMENT ON COLUMN raamaesha.events.occurred_at IS
'Timestamp at which the business event occurred.';


COMMENT ON COLUMN raamaesha.events.correlation_id IS
'Optional identifier used to correlate the event across requests, workflows, services, and distributed operations.';


COMMENT ON COLUMN raamaesha.events.payload IS
'Structured non-secret data describing the event occurrence.';


COMMENT ON COLUMN raamaesha.events.created_at IS
'Timestamp when the immutable event occurrence was persisted.';


-- =============================================================================
-- Event Indexes
-- =============================================================================

CREATE INDEX idx_events_organization
    ON raamaesha.events (organization_id);


CREATE INDEX idx_events_actor
    ON raamaesha.events (actor_id);


CREATE INDEX idx_events_event_type
    ON raamaesha.events (event_type);


CREATE INDEX idx_events_occurred_at
    ON raamaesha.events (occurred_at DESC);


CREATE INDEX idx_events_correlation
    ON raamaesha.events (correlation_id)
    WHERE correlation_id IS NOT NULL;


CREATE INDEX idx_events_organization_occurred_at
    ON raamaesha.events
    (
        organization_id,
        occurred_at DESC
    );


CREATE INDEX idx_events_organization_event_type_occurred_at
    ON raamaesha.events
    (
        organization_id,
        event_type,
        occurred_at DESC
    );


-- =============================================================================
-- Immutable Event Enforcement
-- =============================================================================
--
-- Event occurrences are append-only.
-- Any UPDATE or DELETE operation is rejected at the database boundary.
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.prevent_event_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
BEGIN
    RAISE EXCEPTION
        'Immutable event occurrence cannot be %',
        TG_OP
        USING ERRCODE = '55000';

    RETURN NULL;
END;
$$;


COMMENT ON FUNCTION raamaesha.prevent_event_mutation()
IS
'Prevents UPDATE and DELETE operations on immutable Event Platform event occurrences.';


CREATE TRIGGER trg_events_immutable
BEFORE UPDATE OR DELETE
ON raamaesha.events
FOR EACH ROW
EXECUTE FUNCTION raamaesha.prevent_event_mutation();


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;

