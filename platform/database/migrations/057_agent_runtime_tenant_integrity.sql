-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 057_agent_runtime_tenant_integrity.sql
-- Module    : Agent Runtime
--
-- Purpose:
--   Enforces tenant ownership integrity across the Agent Runtime hierarchy.
--
-- Architecture:
--   Organization
--       |
--       +-- Agent Instance
--               |
--               +-- Agent Run
--                       |
--                       +-- Agent Run Step
--
-- Responsibilities:
--   - Prevent cross-tenant Agent Run / Agent Instance associations
--   - Prevent cross-tenant Agent Run Step / Agent Run associations
--   - Preserve Agent Instance / Agent Version integrity
--   - Enforce tenant boundaries declaratively through composite foreign keys
--
-- Design Principles:
--   - Prefer declarative PostgreSQL integrity over trigger-based enforcement
--   - Do not duplicate runtime state
--   - Preserve existing Agent Instance / Agent Version relationship
--   - Preserve existing lifecycle semantics
--   - No secrets or execution payloads are introduced
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. Agent Instance Tenant Identity
-- =============================================================================
--
-- Creates a composite candidate key so Agent Runs can reference both the
-- Agent Instance and its owning organization in one declarative constraint.
--

ALTER TABLE raamaesha.agent_instances
    ADD CONSTRAINT uq_agent_instances_id_organization
    UNIQUE (id, organization_id);

-- =============================================================================
-- 2. Agent Run Tenant Integrity
-- =============================================================================
--
-- Replaces the tenant-blind Agent Instance reference with an additional
-- composite foreign key that requires the Agent Run organization to match
-- the Agent Instance organization.
--

ALTER TABLE raamaesha.agent_runs
    ADD CONSTRAINT fk_agent_runs_agent_instance_organization
    FOREIGN KEY (agent_instance_id, organization_id)
    REFERENCES raamaesha.agent_instances(id, organization_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

-- =============================================================================
-- 3. Agent Run Tenant Identity
-- =============================================================================
--
-- Creates a composite candidate key so Agent Run Steps can reference both
-- the Agent Run and its owning organization in one declarative constraint.
--

ALTER TABLE raamaesha.agent_runs
    ADD CONSTRAINT uq_agent_runs_id_organization
    UNIQUE (id, organization_id);

-- =============================================================================
-- 4. Replace Tenant-Blind Agent Run Step Reference
-- =============================================================================
--
-- The existing Agent Run foreign key guarantees that the referenced run
-- exists, but does not guarantee that both records belong to the same
-- organization.
--
-- Replace it with the tenant-aware composite foreign key.
--

ALTER TABLE raamaesha.agent_run_steps
    DROP CONSTRAINT fk_agent_run_steps_run;

ALTER TABLE raamaesha.agent_run_steps
    ADD CONSTRAINT fk_agent_run_steps_run_organization
    FOREIGN KEY (agent_run_id, organization_id)
    REFERENCES raamaesha.agent_runs(id, organization_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT;

COMMIT;

-- =============================================================================
-- End of Migration 057
-- =============================================================================
