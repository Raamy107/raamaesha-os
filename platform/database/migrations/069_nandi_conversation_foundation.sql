-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 069_nandi_conversation_foundation.sql
-- Module    : Conversation Foundation
--
-- Purpose:
--   Establishes durable, tenant-safe conversation and message storage.
--
-- Architecture:
--
--   Organization
--        |
--        v
--   Conversation
--        |
--        v
--   Conversation Message
--        |
--        +---- optional Agent Invocation
--
-- Responsibilities:
--   1. Durable conversation identity
--   2. Tenant ownership
--   3. Conversation lifecycle
--   4. Durable message history
--   5. Deterministic message ordering
--   6. Actor attribution
--   7. Optional Nandi invocation traceability
--   8. Safe extensible metadata
--   9. Soft deletion
--
-- Explicitly NOT included:
--   - Agent invocation lifecycle
--   - Agent run lifecycle
--   - AI execution
--   - Model selection
--   - Governance decisions
--   - Prompts as a separate persistence system
--   - Hidden chain-of-thought
--   - Agent memory
--   - RAG / knowledge storage
--   - Embeddings
--   - Usage / cost accounting
--   - Provider credentials
--   - API keys or access tokens
--   - Conversation participant membership
--   - External channel adapters
--
-- Dependencies:
--   007_identity_actor.sql
--   058_nandi_invocation_foundation.sql
--   068_nandi_ai_execution_foundation.sql
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- 1. ENUM : Conversation Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'conversation_status'
    ) THEN
        CREATE TYPE raamaesha.conversation_status AS ENUM (
            'active',
            'archived',
            'closed'
        );
    END IF;
END
$$;

-- =============================================================================
-- 2. ENUM : Conversation Message Role
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typnamespace = 'raamaesha'::regnamespace
          AND typname = 'conversation_message_role'
    ) THEN
        CREATE TYPE raamaesha.conversation_message_role AS ENUM (
            'user',
            'assistant',
            'system',
            'tool'
        );
    END IF;
END
$$;

-- =============================================================================
-- 3. Conversations
-- =============================================================================

CREATE TABLE raamaesha.conversations
(
    id UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id UUID
        NOT NULL,

    title TEXT,

    status raamaesha.conversation_status
        NOT NULL
        DEFAULT 'active',

    metadata JSONB
        NOT NULL
        DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by UUID,

    updated_by UUID,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_conversations
        PRIMARY KEY (id),

    CONSTRAINT uq_conversations_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT fk_conversations_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_conversations_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_conversations_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_conversations_title_not_blank
        CHECK (
            title IS NULL
            OR length(trim(title)) > 0
        ),

    CONSTRAINT chk_conversations_metadata_object
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )
);

-- =============================================================================
-- 4. Conversation Messages
-- =============================================================================

CREATE TABLE raamaesha.conversation_messages
(
    id UUID
        NOT NULL
        DEFAULT gen_random_uuid(),

    organization_id UUID
        NOT NULL,

    conversation_id UUID
        NOT NULL,

    sequence_no BIGINT
        NOT NULL,

    message_role raamaesha.conversation_message_role
        NOT NULL,

    actor_id UUID,

    content TEXT
        NOT NULL,

    metadata JSONB
        NOT NULL
        DEFAULT '{}'::jsonb,

    agent_invocation_id UUID,

    created_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    updated_at TIMESTAMPTZ
        NOT NULL
        DEFAULT CURRENT_TIMESTAMP,

    created_by UUID,

    updated_by UUID,

    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_conversation_messages
        PRIMARY KEY (id),

    CONSTRAINT uq_conversation_messages_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT uq_conversation_messages_sequence
        UNIQUE (conversation_id, sequence_no),

    CONSTRAINT fk_conversation_messages_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_conversation_messages_conversation
        FOREIGN KEY (conversation_id, organization_id)
        REFERENCES raamaesha.conversations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_conversation_messages_actor
        FOREIGN KEY (actor_id)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_conversation_messages_agent_invocation
        FOREIGN KEY (agent_invocation_id, organization_id)
        REFERENCES raamaesha.agent_invocations(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_conversation_messages_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_conversation_messages_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_conversation_messages_sequence_positive
        CHECK (sequence_no > 0),

    CONSTRAINT chk_conversation_messages_content_not_blank
        CHECK (length(trim(content)) > 0),

    CONSTRAINT chk_conversation_messages_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);

-- =============================================================================
-- 5. Conversation Indexes
-- =============================================================================

CREATE INDEX ix_conversations_organization
    ON raamaesha.conversations (organization_id);

CREATE INDEX ix_conversations_organization_status
    ON raamaesha.conversations (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX ix_conversations_created_at
    ON raamaesha.conversations (created_at);

CREATE INDEX ix_conversations_deleted_at
    ON raamaesha.conversations (deleted_at);

-- =============================================================================
-- 6. Conversation Message Indexes
-- =============================================================================

CREATE INDEX ix_conversation_messages_organization
    ON raamaesha.conversation_messages (organization_id);


CREATE INDEX ix_conversation_messages_conversation_created_at
    ON raamaesha.conversation_messages (conversation_id, created_at);

CREATE INDEX ix_conversation_messages_agent_invocation
    ON raamaesha.conversation_messages (agent_invocation_id)
    WHERE agent_invocation_id IS NOT NULL;

CREATE INDEX ix_conversation_messages_deleted_at
    ON raamaesha.conversation_messages (deleted_at);

-- =============================================================================
-- 7. Updated At Functions
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_conversations_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION raamaesha.set_conversation_messages_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- =============================================================================
-- 8. Updated At Triggers
-- =============================================================================

CREATE TRIGGER trg_conversations_updated_at
BEFORE UPDATE ON raamaesha.conversations
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_conversations_updated_at();

CREATE TRIGGER trg_conversation_messages_updated_at
BEFORE UPDATE ON raamaesha.conversation_messages
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_conversation_messages_updated_at();

-- =============================================================================
-- 9. Message Immutability
-- =============================================================================
-- Message identity, ordering, role, content and execution linkage represent
-- durable conversation history and must not be rewritten after creation.
-- Corrected history should be represented by a new message where appropriate.

CREATE OR REPLACE FUNCTION raamaesha.prevent_conversation_message_identity_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.organization_id IS DISTINCT FROM OLD.organization_id
       OR NEW.conversation_id IS DISTINCT FROM OLD.conversation_id
       OR NEW.sequence_no IS DISTINCT FROM OLD.sequence_no
       OR NEW.message_role IS DISTINCT FROM OLD.message_role
       OR NEW.actor_id IS DISTINCT FROM OLD.actor_id
       OR NEW.content IS DISTINCT FROM OLD.content
       OR NEW.agent_invocation_id IS DISTINCT FROM OLD.agent_invocation_id
    THEN
        RAISE EXCEPTION
            'Conversation message identity and durable content are immutable';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_conversation_messages_immutable
BEFORE UPDATE ON raamaesha.conversation_messages
FOR EACH ROW
EXECUTE FUNCTION raamaesha.prevent_conversation_message_identity_change();

-- =============================================================================
-- 10. Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.conversations IS
'Durable tenant-scoped conversation records used as the parent container for conversational history.';

COMMENT ON COLUMN raamaesha.conversations.id IS
'Globally unique conversation identifier.';

COMMENT ON COLUMN raamaesha.conversations.organization_id IS
'Organization that owns the conversation.';

COMMENT ON COLUMN raamaesha.conversations.title IS
'Optional human-readable conversation title.';

COMMENT ON COLUMN raamaesha.conversations.status IS
'Conversation lifecycle status.';

COMMENT ON COLUMN raamaesha.conversations.metadata IS
'Non-secret extensible conversation metadata.';

COMMENT ON TABLE raamaesha.conversation_messages IS
'Durable tenant-scoped messages belonging to a conversation.';

COMMENT ON COLUMN raamaesha.conversation_messages.sequence_no IS
'Strict positive ordering position within the conversation.';

COMMENT ON COLUMN raamaesha.conversation_messages.message_role IS
'Logical role of the message producer within the conversation.';

COMMENT ON COLUMN raamaesha.conversation_messages.actor_id IS
'Optional universal actor responsible for the message.';

COMMENT ON COLUMN raamaesha.conversation_messages.content IS
'Durable message content. Content is immutable after creation.';

COMMENT ON COLUMN raamaesha.conversation_messages.metadata IS
'Non-secret extensible message metadata.';

COMMENT ON COLUMN raamaesha.conversation_messages.agent_invocation_id IS
'Optional tenant-safe reference to the Nandi agent invocation associated with the message.';

-- =============================================================================
-- Migration Complete
-- =============================================================================

COMMIT;

-- =============================================================================
-- End Migration 069
-- =============================================================================
