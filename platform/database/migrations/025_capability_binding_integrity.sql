-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 025_capability_binding_integrity.sql
-- Module    : Capability Binding Integrity
--
-- Purpose:
--   Hardens the referential integrity of capability operation bindings
--   created by Migration 024.
--
-- Responsibilities:
--   - Enforce capability/API ownership consistency
--   - Enforce capability/Event ownership consistency
--   - Correct nullable uniqueness semantics for bindings
--   - Remove the ineffective interface-reference CHECK constraint
--   - Preserve interface-neutral capability operation bindings
--
-- Architecture:
--
--   Capability (022)
--        |
--        +-------------------+
--        |                   |
--        v                   v
--   Capability API      Capability Event
--        |                   |
--        +---------+---------+
--                  |
--                  v
--       Capability Operation Binding (024)
--                  |
--                  v
--       Integration Operation (020)
--                  |
--                  v
--       Operation Contract (021)
--
-- Design Principles:
--   - Correct historical schema without modifying prior migrations
--   - Database-enforced relationship integrity
--   - Capability APIs must belong to the bound capability
--   - Capability Events must belong to the bound capability
--   - Interface-neutral bindings remain valid
--   - One logical binding relationship may exist only once
--   - No execution logic
--   - No workflow execution
--   - No worker scheduling
--   - No queue management
--   - No runtime health-check execution
--   - No plaintext secrets
--
-- Dependencies:
--   - 020_integration_operations.sql
--   - 021_integration_operation_contracts.sql
--   - 022_capability_registry.sql
--   - 023_capability_interfaces.sql
--   - 024_capability_operation_bindings.sql
--
-- PostgreSQL : 17+
-- =============================================================================


BEGIN;


-- =============================================================================
-- Capability API Composite Identity Support
-- =============================================================================
--
-- A capability API is already uniquely identified by its own primary key.
--
-- This additional unique constraint provides a database-level composite key
-- containing both the capability and API identifiers.
--
-- It allows Migration 025 to enforce that a binding's capability_id and
-- capability_api_id always refer to the same capability.
-- =============================================================================

ALTER TABLE raamaesha.capability_apis
    ADD CONSTRAINT uq_capability_apis_capability_id_id
        UNIQUE (capability_id, id);


-- =============================================================================
-- Capability Event Composite Identity Support
-- =============================================================================
--
-- Provides the corresponding composite key required to guarantee that a
-- binding's capability_id and capability_event_id refer to the same
-- capability.
-- =============================================================================

ALTER TABLE raamaesha.capability_events
    ADD CONSTRAINT uq_capability_events_capability_id_id
        UNIQUE (capability_id, id);


-- =============================================================================
-- Remove Ineffective Interface Reference Check
-- =============================================================================
--
-- Migration 024 intentionally permits interface-neutral bindings.
--
-- Its existing CHECK expression is logically tautological and therefore does
-- not enforce any meaningful integrity rule.
--
-- Remove it rather than replacing it with an artificial restriction.
-- =============================================================================

ALTER TABLE raamaesha.capability_operation_bindings
    DROP CONSTRAINT ck_capability_operation_bindings_interface_reference;


-- =============================================================================
-- Enforce Capability/API Ownership Consistency
-- =============================================================================
--
-- A capability operation binding may reference an API interface only when
-- that API belongs to the same capability identified by capability_id.
--
-- The nullable capability_api_id remains valid because API association is
-- optional.
-- =============================================================================

ALTER TABLE raamaesha.capability_operation_bindings
    ADD CONSTRAINT fk_capability_operation_bindings_capability_api_owner
        FOREIGN KEY (capability_id, capability_api_id)
        REFERENCES raamaesha.capability_apis (capability_id, id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;


-- =============================================================================
-- Enforce Capability/Event Ownership Consistency
-- =============================================================================
--
-- A capability operation binding may reference an event interface only when
-- that event belongs to the same capability identified by capability_id.
--
-- The nullable capability_event_id remains valid because event association
-- is optional.
-- =============================================================================

ALTER TABLE raamaesha.capability_operation_bindings
    ADD CONSTRAINT fk_capability_operation_bindings_capability_event_owner
        FOREIGN KEY (capability_id, capability_event_id)
        REFERENCES raamaesha.capability_events (capability_id, id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;


-- =============================================================================
-- Replace Nullable Binding Uniqueness Semantics
-- =============================================================================
--
-- PostgreSQL UNIQUE constraints normally treat NULL values as distinct.
--
-- Migration 024 therefore cannot fully prevent duplicate interface-neutral
-- bindings.
--
-- PostgreSQL 17 supports NULLS NOT DISTINCT, allowing NULL interface
-- references to participate in logical uniqueness.
-- =============================================================================

DROP INDEX ux_capability_operation_bindings_one_active;


CREATE UNIQUE INDEX ux_capability_operation_bindings_relationship
    ON raamaesha.capability_operation_bindings
    (
        capability_id,
        operation_id,
        capability_api_id,
        capability_event_id
    )
    NULLS NOT DISTINCT;


-- =============================================================================
-- Active Binding Uniqueness
-- =============================================================================
--
-- Maintains the lifecycle invariant that only one active, non-deleted
-- binding may exist for a given logical capability/operation/interface
-- relationship.
--
-- NULLS NOT DISTINCT is important here because interface-neutral bindings
-- must also be unique.
-- =============================================================================

CREATE UNIQUE INDEX ux_capability_operation_bindings_one_active
    ON raamaesha.capability_operation_bindings
    (
        capability_id,
        operation_id,
        capability_api_id,
        capability_event_id
    )
    NULLS NOT DISTINCT
    WHERE status = 'active'
      AND deleted_at IS NULL;


-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON CONSTRAINT
    uq_capability_apis_capability_id_id
ON raamaesha.capability_apis IS
'Composite identity supporting database enforcement that a capability API referenced by a binding belongs to the same capability.';


COMMENT ON CONSTRAINT
    uq_capability_events_capability_id_id
ON raamaesha.capability_events IS
'Composite identity supporting database enforcement that a capability event referenced by a binding belongs to the same capability.';


COMMENT ON CONSTRAINT
    fk_capability_operation_bindings_capability_api_owner
ON raamaesha.capability_operation_bindings IS
'Ensures that a referenced capability API belongs to the same capability as the binding.';


COMMENT ON CONSTRAINT
    fk_capability_operation_bindings_capability_event_owner
ON raamaesha.capability_operation_bindings IS
'Ensures that a referenced capability event belongs to the same capability as the binding.';


COMMENT ON INDEX
    raamaesha.ux_capability_operation_bindings_relationship IS
'Ensures one logical capability operation binding relationship exists, treating NULL interface references as equal.';


COMMENT ON INDEX
    raamaesha.ux_capability_operation_bindings_one_active IS
'Ensures one active, non-deleted capability operation binding exists for each logical relationship, including interface-neutral bindings.';


-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;