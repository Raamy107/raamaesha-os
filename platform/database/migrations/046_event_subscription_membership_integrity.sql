-- =============================================================================
-- Migration 046 : Event Subscription Membership Integrity
-- =============================================================================
--
-- Purpose:
--   Harden cross-table lifecycle integrity between event subscriptions
--   and organization memberships.
--
-- Responsibilities:
--   - Ensure active event subscriptions belong to active organization members.
--   - Prevent an active membership from becoming non-current while active
--     event subscriptions remain attached to it.
--   - Serialize subscription validation through the membership row.
--
-- Non-responsibilities:
--   - Event delivery
--   - Queues
--   - Retries
--   - Workers
--   - Webhooks
--   - Event processing
--
-- Dependencies:
--   - 035_organization_memberships.sql
--   - 045_event_subscriptions.sql
--
-- =============================================================================

BEGIN;


-- =============================================================================
-- Event Subscription -> Membership Integrity
-- =============================================================================
--
-- An active, non-deleted event subscription is valid only when its subscriber
-- actor has an active, non-deleted membership in the same organization.
--
-- The membership row is locked before its lifecycle state is inspected.
-- This makes the membership row the synchronization point for concurrent
-- membership/subscription lifecycle changes.
--
-- Historical inactive subscriptions remain permitted.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_active_event_subscription_membership_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
    membership_status public.organization_membership_status;
    membership_deleted_at TIMESTAMPTZ;
BEGIN

    IF NEW.is_active = TRUE
       AND NEW.deleted_at IS NULL
    THEN

        SELECT
            om.status,
            om.deleted_at
        INTO
            membership_status,
            membership_deleted_at
        FROM raamaesha.organization_memberships AS om
        WHERE om.organization_id = NEW.organization_id
          AND om.actor_id = NEW.subscriber_actor_id
          AND om.deleted_at IS NULL
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Active event subscription requires an existing current organization membership: organization_id=%, subscriber_actor_id=%',
                NEW.organization_id,
                NEW.subscriber_actor_id
                USING ERRCODE = '23514';
        END IF;

        IF membership_status <> 'active'
           OR membership_deleted_at IS NOT NULL
        THEN
            RAISE EXCEPTION
                'Active event subscription requires an active, non-deleted organization membership: organization_id=%, subscriber_actor_id=%, status=%, deleted_at=%',
                NEW.organization_id,
                NEW.subscriber_actor_id,
                membership_status,
                membership_deleted_at
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Event Subscription -> Membership
-- =============================================================================

CREATE TRIGGER trg_event_subscriptions_current_membership_integrity
BEFORE INSERT OR UPDATE OF
    organization_id,
    subscriber_actor_id,
    is_active,
    deleted_at
ON raamaesha.event_subscriptions
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_active_event_subscription_membership_integrity();


-- =============================================================================
-- Membership -> Active Event Subscription Integrity
-- =============================================================================
--
-- A membership cannot become non-current while an active event subscription
-- remains attached to the same organization/actor relationship.
--
-- The membership row is already being modified by the current transaction,
-- therefore it provides the required row-level synchronization point for
-- concurrent lifecycle changes involving that membership.
--
-- The event subscription must be deactivated or soft-deleted before the
-- membership lifecycle can be ended.
-- =============================================================================

CREATE OR REPLACE FUNCTION
    raamaesha.enforce_membership_current_event_subscription_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
BEGIN

    IF (
        NEW.status <> 'active'
        OR NEW.deleted_at IS NOT NULL
    )
    AND (
        OLD.status = 'active'
        AND OLD.deleted_at IS NULL
    )
    THEN

        IF EXISTS
        (
            SELECT 1
            FROM raamaesha.event_subscriptions AS es
            WHERE es.organization_id = NEW.organization_id
              AND es.subscriber_actor_id = NEW.actor_id
              AND es.is_active = TRUE
              AND es.deleted_at IS NULL
        )
        THEN
            RAISE EXCEPTION
                'Organization membership cannot become non-current while active event subscriptions exist: organization_id=%, actor_id=%',
                NEW.organization_id,
                NEW.actor_id
                USING ERRCODE = '23514';
        END IF;

    END IF;

    RETURN NEW;
END;
$$;


-- =============================================================================
-- Trigger : Membership -> Active Event Subscription
-- =============================================================================

CREATE TRIGGER trg_organization_memberships_current_event_subscription_integrity
BEFORE UPDATE OF status, deleted_at
ON raamaesha.organization_memberships
FOR EACH ROW
EXECUTE FUNCTION
    raamaesha.enforce_membership_current_event_subscription_integrity();


-- =============================================================================
-- Function Documentation
-- =============================================================================

COMMENT ON FUNCTION
    raamaesha.enforce_active_event_subscription_membership_integrity()
IS
'Ensures that an active, non-deleted event subscription belongs to an active, non-deleted organization membership and locks the membership row during validation.';


COMMENT ON FUNCTION
    raamaesha.enforce_membership_current_event_subscription_integrity()
IS
'Prevents an organization membership from becoming non-current while active, non-deleted event subscriptions remain attached to the same organization and actor.';


-- =============================================================================
-- Trigger Documentation
-- =============================================================================

COMMENT ON TRIGGER
    trg_event_subscriptions_current_membership_integrity
ON raamaesha.event_subscriptions IS
'Enforces that current event subscriptions belong to current active organization memberships and serializes validation through the membership row.';


COMMENT ON TRIGGER
    trg_organization_memberships_current_event_subscription_integrity
ON raamaesha.organization_memberships IS
'Prevents an organization membership from becoming non-current while active event subscriptions remain attached to the organization and actor.';


COMMIT;

