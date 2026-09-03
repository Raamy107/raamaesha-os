-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 047_event_deliveries.sql
-- Module    : Event Platform
--
-- Purpose:
--   Establishes the durable foundation for event delivery intent.
--
-- Responsibilities:
--   - Event occurrence to subscription delivery relationship
--   - Durable delivery identity
--   - One delivery record per event/subscription pair
--   - Delivery creation timestamp
--
-- Non-Responsibilities:
--   - Delivery execution
--   - Queues
--   - Workers
--   - Retries
--   - Delivery attempts
--   - Webhooks
--   - Event processing
--   - Provider execution
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

CREATE TABLE raamaesha.event_deliveries
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    event_id
        UUID
        NOT NULL,

    subscription_id
        UUID
        NOT NULL,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_event_deliveries
        PRIMARY KEY (id),

    CONSTRAINT fk_event_deliveries_event
        FOREIGN KEY (event_id)
        REFERENCES raamaesha.events (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_event_deliveries_subscription
        FOREIGN KEY (subscription_id)
        REFERENCES raamaesha.event_subscriptions (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT uq_event_deliveries_event_subscription
        UNIQUE (event_id, subscription_id)
);

COMMENT ON TABLE raamaesha.event_deliveries IS
'Durable delivery intents connecting immutable Event Platform occurrences to event subscriptions. Delivery execution is handled by later Event Platform components.';

COMMENT ON COLUMN raamaesha.event_deliveries.id IS
'Globally unique identifier for the event delivery intent.';

COMMENT ON COLUMN raamaesha.event_deliveries.event_id IS
'Immutable event occurrence associated with this delivery intent.';

COMMENT ON COLUMN raamaesha.event_deliveries.subscription_id IS
'Event subscription that receives this delivery intent.';

COMMENT ON COLUMN raamaesha.event_deliveries.created_at IS
'Timestamp when the delivery intent was persisted.';

CREATE INDEX idx_event_deliveries_event
    ON raamaesha.event_deliveries (event_id);

CREATE INDEX idx_event_deliveries_subscription
    ON raamaesha.event_deliveries (subscription_id);

CREATE INDEX idx_event_deliveries_created_at
    ON raamaesha.event_deliveries (created_at);

COMMIT;
'@ | Set-Content .\platform\database\migrations\047_event_deliveries.sql
