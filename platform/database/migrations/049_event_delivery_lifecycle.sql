-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 049_event_delivery_lifecycle.sql
-- Module    : Event Platform
--
-- Purpose:
--   Establish the durable lifecycle foundation for event delivery intents.
--
-- Responsibilities:
--   - Define event delivery lifecycle status
--   - Record delivery processing start timestamp
--   - Record delivery completion timestamp
--   - Establish database-level lifecycle consistency
--
-- Lifecycle:
--   pending -> processing -> delivered
--                     \
--                      -> failed
--
-- Non-Responsibilities:
--   - Delivery attempts
--   - Retry scheduling
--   - Retry counters
--   - Queues
--   - Workers
--   - Webhooks
--   - Event processing
--   - Provider execution
--   - Provider-specific delivery logic
--
-- Dependencies:
--   - 047_event_deliveries.sql
--   - 048_event_delivery_integrity.sql
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

CREATE TYPE public.event_delivery_status AS ENUM
(
    'pending',
    'processing',
    'delivered',
    'failed'
);

COMMENT ON TYPE public.event_delivery_status IS
'Lifecycle state of a durable event delivery intent.';

ALTER TABLE raamaesha.event_deliveries
    ADD COLUMN status
        public.event_delivery_status
        NOT NULL
        DEFAULT 'pending',

    ADD COLUMN started_at
        TIMESTAMPTZ,

    ADD COLUMN completed_at
        TIMESTAMPTZ;

ALTER TABLE raamaesha.event_deliveries
    ADD CONSTRAINT ck_event_deliveries_processing_started
        CHECK (
            status <> 'processing'
            OR started_at IS NOT NULL
        ),

    ADD CONSTRAINT ck_event_deliveries_processing_not_completed
        CHECK (
            status <> 'processing'
            OR completed_at IS NULL
        ),

    ADD CONSTRAINT ck_event_deliveries_pending_not_started
        CHECK (
            status <> 'pending'
            OR started_at IS NULL
        ),

    ADD CONSTRAINT ck_event_deliveries_pending_not_completed
        CHECK (
            status <> 'pending'
            OR completed_at IS NULL
        ),

    ADD CONSTRAINT ck_event_deliveries_terminal_started
        CHECK (
            status IN ('pending', 'processing')
            OR started_at IS NOT NULL
        ),

    ADD CONSTRAINT ck_event_deliveries_terminal_completed
        CHECK (
            status IN ('pending', 'processing')
            OR completed_at IS NOT NULL
        );

CREATE INDEX idx_event_deliveries_status
    ON raamaesha.event_deliveries (status);

CREATE INDEX idx_event_deliveries_pending
    ON raamaesha.event_deliveries (created_at)
    WHERE status = 'pending';

CREATE INDEX idx_event_deliveries_processing
    ON raamaesha.event_deliveries (started_at)
    WHERE status = 'processing';

CREATE INDEX idx_event_deliveries_completed
    ON raamaesha.event_deliveries (completed_at)
    WHERE status IN ('delivered', 'failed');

COMMENT ON COLUMN raamaesha.event_deliveries.status IS
'Current lifecycle state of the event delivery intent.';

COMMENT ON COLUMN raamaesha.event_deliveries.started_at IS
'Timestamp at which delivery processing began.';

COMMENT ON COLUMN raamaesha.event_deliveries.completed_at IS
'Timestamp at which delivery processing reached a terminal lifecycle state.';

COMMENT ON CONSTRAINT
    ck_event_deliveries_processing_started
ON raamaesha.event_deliveries IS
'Requires processing event deliveries to have a recorded processing start timestamp.';

COMMENT ON CONSTRAINT
    ck_event_deliveries_processing_not_completed
ON raamaesha.event_deliveries IS
'Prevents processing event deliveries from having a completion timestamp.';

COMMENT ON CONSTRAINT
    ck_event_deliveries_pending_not_started
ON raamaesha.event_deliveries IS
'Prevents pending event deliveries from having a processing start timestamp.';

COMMENT ON CONSTRAINT
    ck_event_deliveries_pending_not_completed
ON raamaesha.event_deliveries IS
'Prevents pending event deliveries from having a completion timestamp.';

COMMENT ON CONSTRAINT
    ck_event_deliveries_terminal_started
ON raamaesha.event_deliveries IS
'Requires terminal event deliveries to have a recorded processing start timestamp.';

COMMENT ON CONSTRAINT
    ck_event_deliveries_terminal_completed
ON raamaesha.event_deliveries IS
'Requires terminal event deliveries to have a recorded completion timestamp.';

COMMIT;
