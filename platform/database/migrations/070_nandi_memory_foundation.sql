-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 070_nandi_memory_foundation.sql
-- Module    : Nandi AI Control Plane
--
-- Purpose:
--   Establishes the durable Memory Foundation for Nandi and future AI agents.
--
-- Architecture:
--
--   Conversation
--       -> Conversation Message
--              |
--              v
--        Memory Foundation
--              |
--              +--> optional actor association
--              +--> optional conversation provenance
--              +--> optional message provenance
--              +--> optional invocation provenance
--
-- Memory is organization-owned durable information.
--
-- This migration intentionally does NOT implement:
--   - Knowledge documents
--   - RAG
--   - Embeddings
--   - Vector storage
--   - Similarity search
--   - Retrieval pipelines
--   - Chunking
--   - AI provider/model selection
--   - Prompt persistence
--   - Hidden chain-of-thought
--   - Usage/cost accounting
--   - Agent execution lifecycle
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. MEMORY TYPE
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'memory_type'
    ) THEN
        CREATE TYPE raamaesha.memory_type AS ENUM (
            'fact',
            'preference',
            'instruction',
            'relationship',
            'context'
        );
    END IF;
END
$$;

-- =============================================================================
-- 2. MEMORY STATUS
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'memory_status'
    ) THEN
        CREATE TYPE raamaesha.memory_status AS ENUM (
            'active',
            'archived',
            'superseded'
        );
    END IF;
END
$$;

-- =============================================================================
-- 3. MEMORIES
-- =============================================================================

CREATE TABLE raamaesha.memories
(
    id UUID NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id UUID NOT NULL,

    actor_id UUID,

    memory_type raamaesha.memory_type NOT NULL,

    status raamaesha.memory_status NOT NULL
        DEFAULT 'active',

    content TEXT NOT NULL,

    conversation_id UUID,

    conversation_message_id UUID,

    agent_invocation_id UUID,

    metadata JSONB NOT NULL
        DEFAULT '{}'::JSONB,

    created_by UUID,

    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_memories
        PRIMARY KEY (id),

    CONSTRAINT fk_memories_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_memories_actor
        FOREIGN KEY (actor_id)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_memories_conversation
        FOREIGN KEY (conversation_id, organization_id)
        REFERENCES raamaesha.conversations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_memories_conversation_message
        FOREIGN KEY (conversation_message_id, organization_id)
        REFERENCES raamaesha.conversation_messages(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_memories_agent_invocation
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_memories_created_by_actor
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_memories_updated_by_actor
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT uq_memories_id_organization
        UNIQUE (
            id,
            organization_id
        ),

    CONSTRAINT ck_memories_content_not_blank
        CHECK (
            length(btrim(content)) > 0
        ),

    CONSTRAINT ck_memories_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        ),

    CONSTRAINT ck_memories_message_requires_conversation
        CHECK (
            conversation_message_id IS NULL
            OR conversation_id IS NOT NULL
        )
);

-- =============================================================================
-- 4. INDEXES
-- =============================================================================

CREATE INDEX idx_memories_organization_id
    ON raamaesha.memories (
        organization_id
    );

CREATE INDEX idx_memories_organization_status
    ON raamaesha.memories (
        organization_id,
        status
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_memories_organization_type
    ON raamaesha.memories (
        organization_id,
        memory_type
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_memories_actor_id
    ON raamaesha.memories (
        organization_id,
        actor_id
    )
    WHERE actor_id IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_memories_conversation_id
    ON raamaesha.memories (
        organization_id,
        conversation_id
    )
    WHERE conversation_id IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_memories_conversation_message_id
    ON raamaesha.memories (
        organization_id,
        conversation_message_id
    )
    WHERE conversation_message_id IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_memories_agent_invocation_id
    ON raamaesha.memories (
        organization_id,
        agent_invocation_id
    )
    WHERE agent_invocation_id IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_memories_deleted_at
    ON raamaesha.memories (
        organization_id,
        deleted_at
    );

CREATE INDEX idx_memories_organization_created_at
    ON raamaesha.memories (
        organization_id,
        created_at
    );

-- =============================================================================
-- 5. UPDATED_AT FUNCTION
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_memories_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- 6. MEMORY MUTABILITY / PROVENANCE PROTECTION
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.enforce_memories_mutability()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id THEN
        RAISE EXCEPTION
            'Memory identity is immutable: id cannot be changed';
    END IF;

    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
        RAISE EXCEPTION
            'Memory tenant is immutable: organization_id cannot be changed';
    END IF;

    IF NEW.actor_id IS DISTINCT FROM OLD.actor_id THEN
        RAISE EXCEPTION
            'Memory actor association is immutable: actor_id cannot be changed';
    END IF;

    IF NEW.conversation_id IS DISTINCT FROM OLD.conversation_id THEN
        RAISE EXCEPTION
            'Memory conversation provenance is immutable: conversation_id cannot be changed';
    END IF;

    IF NEW.conversation_message_id IS DISTINCT FROM OLD.conversation_message_id THEN
        RAISE EXCEPTION
            'Memory message provenance is immutable: conversation_message_id cannot be changed';
    END IF;

    IF NEW.agent_invocation_id IS DISTINCT FROM OLD.agent_invocation_id THEN
        RAISE EXCEPTION
            'Memory invocation provenance is immutable: agent_invocation_id cannot be changed';
    END IF;

    IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION
            'Memory creation timestamp is immutable: created_at cannot be changed';
    END IF;

    IF NEW.created_by IS DISTINCT FROM OLD.created_by THEN
        RAISE EXCEPTION
            'Memory creation provenance is immutable: created_by cannot be changed';
    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- 7. CROSS-REFERENCE VALIDATION
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.validate_memory_provenance()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_message_conversation_id UUID;
BEGIN
    IF NEW.conversation_message_id IS NOT NULL THEN

        SELECT cm.conversation_id
        INTO v_message_conversation_id
        FROM raamaesha.conversation_messages AS cm
        WHERE cm.id = NEW.conversation_message_id
          AND cm.organization_id = NEW.organization_id
          AND cm.deleted_at IS NULL;

        IF v_message_conversation_id IS NULL THEN
            RAISE EXCEPTION
                'Memory provenance validation failed: conversation message % is unavailable for organization %',
                NEW.conversation_message_id,
                NEW.organization_id;
        END IF;

        IF v_message_conversation_id IS DISTINCT FROM NEW.conversation_id THEN
            RAISE EXCEPTION
                'Memory provenance validation failed: conversation_id does not match conversation_message_id';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

-- =============================================================================
-- 8. TRIGGERS
-- =============================================================================

CREATE TRIGGER trg_memories_updated_at
BEFORE UPDATE ON raamaesha.memories
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_memories_updated_at();

CREATE TRIGGER trg_memories_immutability
BEFORE UPDATE ON raamaesha.memories
FOR EACH ROW
EXECUTE FUNCTION raamaesha.enforce_memories_mutability();

CREATE TRIGGER trg_memories_provenance_validation
BEFORE INSERT OR UPDATE ON raamaesha.memories
FOR EACH ROW
EXECUTE FUNCTION raamaesha.validate_memory_provenance();

-- =============================================================================
-- 9. COMMENTS
-- =============================================================================

COMMENT ON TABLE raamaesha.memories IS
'Durable organization-owned memory records used by the Nandi AI Control Plane and future AI agents. Knowledge/RAG, embeddings, vectors, retrieval, and usage accounting are intentionally outside this foundation.';

COMMENT ON COLUMN raamaesha.memories.id IS
'Stable UUID identity of the memory record. Immutable after creation.';

COMMENT ON COLUMN raamaesha.memories.organization_id IS
'Mandatory tenant ownership boundary for the memory record. Immutable after creation.';

COMMENT ON COLUMN raamaesha.memories.actor_id IS
'Optional actor associated with the memory. This is an association, not the tenant ownership boundary. Immutable after creation.';

COMMENT ON COLUMN raamaesha.memories.memory_type IS
'Semantic category of durable memory: fact, preference, instruction, relationship, or context.';

COMMENT ON COLUMN raamaesha.memories.status IS
'Lifecycle status of the durable memory. Soft deletion is represented separately by deleted_at.';

COMMENT ON COLUMN raamaesha.memories.content IS
'Durable human- or machine-readable memory content. Embeddings and vector representations are intentionally excluded.';

COMMENT ON COLUMN raamaesha.memories.conversation_id IS
'Optional conversation from which the memory originated. Immutable provenance reference.';

COMMENT ON COLUMN raamaesha.memories.conversation_message_id IS
'Optional specific conversation message from which the memory originated. Immutable provenance reference.';

COMMENT ON COLUMN raamaesha.memories.agent_invocation_id IS
'Optional agent invocation that produced or established the memory. Immutable provenance reference.';

COMMENT ON COLUMN raamaesha.memories.metadata IS
'Extensible structured metadata for the memory. Must remain a JSON object.';

COMMENT ON COLUMN raamaesha.memories.deleted_at IS
'Soft-delete timestamp. NULL indicates that the record has not been soft-deleted.';

-- =============================================================================
-- 10. MIGRATION VALIDATION
-- =============================================================================

DO $$
BEGIN

    IF to_regclass('raamaesha.memories') IS NULL THEN
        RAISE EXCEPTION
            'Migration 070 validation failed: raamaesha.memories does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'memory_type'
    ) THEN
        RAISE EXCEPTION
            'Migration 070 validation failed: raamaesha.memory_type does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'memory_status'
    ) THEN
        RAISE EXCEPTION
            'Migration 070 validation failed: raamaesha.memory_status does not exist';
    END IF;

    IF to_regclass('raamaesha.organizations') IS NULL THEN
        RAISE EXCEPTION
            'Migration 070 validation failed: organizations table does not exist';
    END IF;

    IF to_regclass('raamaesha.actors') IS NULL THEN
        RAISE EXCEPTION
            'Migration 070 validation failed: actors table does not exist';
    END IF;

    IF to_regclass('raamaesha.conversations') IS NULL THEN
        RAISE EXCEPTION
            'Migration 070 validation failed: conversations table does not exist';
    END IF;

    IF to_regclass('raamaesha.conversation_messages') IS NULL THEN
        RAISE EXCEPTION
            'Migration 070 validation failed: conversation_messages table does not exist';
    END IF;

    IF to_regclass('raamaesha.agent_invocations') IS NULL THEN
        RAISE EXCEPTION
            'Migration 070 validation failed: agent_invocations table does not exist';
    END IF;

END
$$;

COMMIT;

-- =============================================================================
-- End Migration 070
-- =============================================================================
