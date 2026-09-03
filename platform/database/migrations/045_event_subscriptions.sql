-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 045_event_subscriptions.sql
-- Module    : Event Platform
--
-- Purpose:
--   Establishes the foundation for event subscriptions.
--
-- Responsibilities:
--   - Organization-scoped event subscriptions
--   - Subscriber actor identity
--   - Event type subscription identity
--   - Subscription lifecycle
--
-- Non-Responsibilities:
--   - Event delivery
--   - Queues
--   - Retries
--   - Workers
--   - Webhooks
--   - Event processing
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Event Subscriptions
-- =============================================================================

CREATE TABLE raamaesha.event_subscriptions
(
    id
        UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id
        UUID
        NOT NULL,

    subscriber_actor_id
        UUID
        NOT NULL,

    event_type
        TEXT
        NOT NULL,

    is_active
        BOOLEAN
        NOT NULL
        DEFAULT TRUE,

    created_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by
        UUID,

    updated_at
        TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_by
        UUID,

    deleted_at
        TIMESTAMPTZ,

    deleted_by
        UUID,

    CONSTRAINT pk_event_subscriptions
        PRIMARY KEY (id),

    CONSTRAINT fk_event_subscriptions_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_event_subscriptions_subscriber_actor
        FOREIGN KEY (subscriber_actor_id)
        REFERENCES raamaesha.actors (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT ck_event_subscriptions_event_type_not_blank
        CHECK (length(trim(event_type)) > 0),

    CONSTRAINT ck_event_subscriptions_active_not_deleted
        CHECK (
            is_active = FALSE
            OR deleted_at IS NULL
        )
);

-- =============================================================================
-- Table Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.event_subscriptions IS
'Defines organization-scoped subscriptions for immutable Event Platform event types. Delivery and processing are handled by later Event Platform components.';

COMMENT ON COLUMN raamaesha.event_subscriptions.id IS
'Globally unique identifier for the event subscription.';

COMMENT ON COLUMN raamaesha.event_subscriptions.organization_id IS
'Organization that owns the event subscription.';

COMMENT ON COLUMN raamaesha.event_subscriptions.subscriber_actor_id IS
'Actor that owns or represents the subscription.';

COMMENT ON COLUMN raamaesha.event_subscriptions.event_type IS
'Event type to which the subscriber is subscribed.';

COMMENT ON COLUMN raamaesha.event_subscriptions.is_active IS
'Indicates whether the subscription is currently active.';

COMMENT ON COLUMN raamaesha.event_subscriptions.created_at IS
'Timestamp when the subscription was created.';

COMMENT ON COLUMN raamaesha.event_subscriptions.created_by IS
'Actor that created the subscription.';

COMMENT ON COLUMN raamaesha.event_subscriptions.updated_at IS
'Timestamp when the subscription was last updated.';

COMMENT ON COLUMN raamaesha.event_subscriptions.updated_by IS
'Actor that last updated the subscription.';

COMMENT ON COLUMN raamaesha.event_subscriptions.deleted_at IS
'Soft deletion timestamp. NULL indicates the subscription has not been soft-deleted.';

COMMENT ON COLUMN raamaesha.event_subscriptions.deleted_by IS
'Actor that soft-deleted the subscription.';

-- =============================================================================
-- Secondary Indexes
-- =============================================================================

CREATE INDEX idx_event_subscriptions_organization
    ON raamaesha.event_subscriptions (organization_id);

CREATE INDEX idx_event_subscriptions_subscriber_actor
    ON raamaesha.event_subscriptions (subscriber_actor_id);

CREATE INDEX idx_event_subscriptions_event_type
    ON raamaesha.event_subscriptions (event_type);

CREATE INDEX idx_event_subscriptions_is_active
    ON raamaesha.event_subscriptions (is_active);

CREATE INDEX idx_event_subscriptions_deleted_at
    ON raamaesha.event_subscriptions (deleted_at);

CREATE INDEX idx_event_subscriptions_organization_event_type
    ON raamaesha.event_subscriptions
    (
        organization_id,
        event_type
    );

-- =============================================================================
-- Production Integrity: One Current Subscription
-- =============================================================================

CREATE UNIQUE INDEX ux_event_subscriptions_one_current
    ON raamaesha.event_subscriptions
    (
        organization_id,
        subscriber_actor_id,
        event_type
    )
    WHERE is_active = TRUE
      AND deleted_at IS NULL;

-- =============================================================================
-- Audit Trigger
-- =============================================================================

CREATE TRIGGER trg_event_subscriptions_set_updated_at
BEFORE UPDATE
ON raamaesha.event_subscriptions
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_updated_at();

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;



