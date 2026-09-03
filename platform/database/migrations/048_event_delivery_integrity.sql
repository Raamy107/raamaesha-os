-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 048_event_delivery_integrity.sql
-- Module    : Event Platform
--
-- Purpose:
--   Harden cross-table integrity of durable event delivery intents.
--
-- Responsibilities:
--   - Ensure an event delivery connects records from the same organization.
--   - Serialize delivery validation through the subscription row.
--   - Prevent mutation of the event/subscription relationship after creation.
--   - Prevent subscription tenant reassignment while deliveries reference it.
--
-- Non-Responsibilities:
--   - Delivery lifecycle status
--   - Delivery execution
--   - Delivery attempts
--   - Retries
--   - Retry scheduling
--   - Queues
--   - Workers
--   - Webhooks
--   - Event processing
--   - Provider execution
--   - Subscription activation policy
--
-- Dependencies:
--   - 044_event_platform.sql
--   - 045_event_subscriptions.sql
--   - 046_event_subscription_membership_integrity.sql
--   - 047_event_deliveries.sql
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- ============================================================================
-- Event Delivery Tenant Integrity
-- ============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_event_delivery_tenant_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    event_organization_id UUID;
    subscription_organization_id UUID;
BEGIN

    SELECT
        es.organization_id
    INTO
        subscription_organization_id
    FROM raamaesha.event_subscriptions AS es
    WHERE es.id = NEW.subscription_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Event delivery requires an existing event subscription: subscription_id=%',
            NEW.subscription_id
            USING ERRCODE = '23503';
    END IF;

    SELECT
        e.organization_id
    INTO
        event_organization_id
    FROM raamaesha.events AS e
    WHERE e.id = NEW.event_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Event delivery requires an existing event occurrence: event_id=%',
            NEW.event_id
            USING ERRCODE = '23503';
    END IF;

    IF event_organization_id <> subscription_organization_id
    THEN
        RAISE EXCEPTION
            'Event delivery cannot cross organization boundaries: event_id=%, subscription_id=%, event_organization_id=%, subscription_organization_id=%',
            NEW.event_id,
            NEW.subscription_id,
            event_organization_id,
            subscription_organization_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_event_deliveries_tenant_integrity
BEFORE INSERT
ON raamaesha.event_deliveries
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_event_delivery_tenant_integrity();


-- ============================================================================
-- Event Delivery Relationship Immutability
-- ============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.prevent_event_delivery_relationship_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN

    IF NEW.event_id IS DISTINCT FROM OLD.event_id
       OR NEW.subscription_id IS DISTINCT FROM OLD.subscription_id
    THEN
        RAISE EXCEPTION
            'Event delivery relationship is immutable: delivery_id=%',
            OLD.id
            USING ERRCODE = '55000';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_event_deliveries_relationship_immutable
BEFORE UPDATE OF event_id, subscription_id
ON raamaesha.event_deliveries
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.prevent_event_delivery_relationship_mutation();


-- ============================================================================
-- Subscription Tenant Reassignment Protection
-- ============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.prevent_event_subscription_organization_reassignment_with_deliveries()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN

    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id
       AND EXISTS
       (
           SELECT 1
           FROM raamaesha.event_deliveries AS ed
           WHERE ed.subscription_id = OLD.id
       )
    THEN
        RAISE EXCEPTION
            'Event subscription organization cannot be changed while delivery intents reference it: subscription_id=%, old_organization_id=%, new_organization_id=%',
            OLD.id,
            OLD.organization_id,
            NEW.organization_id
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_event_subscriptions_delivery_organization_integrity
BEFORE UPDATE OF organization_id
ON raamaesha.event_subscriptions
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.prevent_event_subscription_organization_reassignment_with_deliveries();


-- ============================================================================
-- Documentation
-- ============================================================================

COMMENT ON FUNCTION
    raamaesha.enforce_event_delivery_tenant_integrity()
IS
'Ensures that an event delivery connects an event occurrence and event subscription belonging to the same organization and serializes validation through the subscription row.';

COMMENT ON FUNCTION
    raamaesha.prevent_event_delivery_relationship_mutation()
IS
'Prevents reassignment of the immutable event and subscription relationship of an event delivery intent while allowing future delivery lifecycle fields to change.';

COMMENT ON FUNCTION
    raamaesha.prevent_event_subscription_organization_reassignment_with_deliveries()
IS
'Prevents changing an event subscription organization while delivery intents reference the subscription, preserving tenant consistency of existing delivery relationships.';

COMMENT ON TRIGGER
    trg_event_deliveries_tenant_integrity
ON raamaesha.event_deliveries IS
'Prevents event deliveries from crossing organization boundaries and serializes validation through the referenced subscription row.';

COMMENT ON TRIGGER
    trg_event_deliveries_relationship_immutable
ON raamaesha.event_deliveries IS
'Prevents mutation of the event/subscription relationship after an event delivery intent has been created.';

COMMENT ON TRIGGER
    trg_event_subscriptions_delivery_organization_integrity
ON raamaesha.event_subscriptions IS
'Prevents subscription tenant reassignment while delivery intents reference the subscription.';

COMMIT;
