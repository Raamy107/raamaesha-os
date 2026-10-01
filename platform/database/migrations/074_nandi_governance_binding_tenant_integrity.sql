-- ============================================================================
-- Migration: 074_nandi_governance_binding_tenant_integrity.sql
-- Purpose: Enforce tenant ownership between Nandi governance decisions and
--          their authoritative capability-operation bindings
-- Owner: RaamaEsha Technologies
-- Architecture:
--   058 Invocation
--       -> 062 Planning
--       -> 072 Capability Gateway
--       -> 063 Governance Decision
--       -> 064 Execution Dispatch
--
--   Governance safeguards:
--       -> 074 Governance Binding Tenant Integrity
--       -> 073 Governance Policy Evaluation / Evidence
--
-- Responsibilities:
--   1. Validate governance decision binding ownership at write time
--   2. Resolve authoritative binding ownership through:
--        capability_operation_bindings
--          -> integration_operations
--          -> integrations
--          -> organization_id
--   3. Prevent cross-tenant governance decisions
--   4. Preserve the existing governance decision model
--
-- Does NOT:
--   - modify migration 063
--   - modify capability-operation binding ownership
--   - add organization_id to capability_operation_bindings
--   - modify integrations or integration operations
--   - change governance decision authority
--   - enforce binding status
--   - execute capabilities or integrations
--   - manage human approval records
--   - store secrets or credentials
--   - store hidden chain-of-thought
--
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. GOVERNANCE DECISION BINDING OWNERSHIP VALIDATION
-- ============================================================================

CREATE OR REPLACE FUNCTION raamaesha.validate_agent_invocation_governance_decision_binding_ownership()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM raamaesha.capability_operation_bindings AS cob
        JOIN raamaesha.integration_operations AS io
            ON io.id = cob.operation_id
        JOIN raamaesha.integrations AS i
            ON i.id = io.integration_id
        WHERE cob.id = NEW.capability_operation_binding_id
          AND i.organization_id = NEW.organization_id
    ) THEN
        RAISE EXCEPTION
            'Capability-operation binding % does not belong to organization %',
            NEW.capability_operation_binding_id,
            NEW.organization_id;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION raamaesha.validate_agent_invocation_governance_decision_binding_ownership()
IS 'Enforces tenant ownership between governance decisions and their authoritative capability-operation bindings.';

-- ============================================================================
-- 2. GOVERNANCE DECISION BINDING OWNERSHIP TRIGGER
-- ============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_agent_invocation_governance_decisions_binding_ownership'
          AND tgrelid = 'raamaesha.agent_invocation_governance_decisions'::regclass
          AND NOT tgisinternal
    ) THEN
        CREATE TRIGGER trg_agent_invocation_governance_decisions_binding_ownership
        BEFORE INSERT OR UPDATE
        ON raamaesha.agent_invocation_governance_decisions
        FOR EACH ROW
        EXECUTE FUNCTION raamaesha.validate_agent_invocation_governance_decision_binding_ownership();
    END IF;
END
$$;

COMMENT ON TRIGGER trg_agent_invocation_governance_decisions_binding_ownership
ON raamaesha.agent_invocation_governance_decisions
IS 'Prevents governance decisions from referencing capability-operation bindings owned by another organization.';

COMMIT;
