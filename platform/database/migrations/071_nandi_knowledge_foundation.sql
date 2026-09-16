-- =============================================================================
-- RaamaEsha OS Founder Edition
-- Migration : 071_nandi_knowledge_foundation.sql
-- Module    : Nandi AI Control Plane / Knowledge & RAG Foundation
--
-- Purpose:
--   Establishes the tenant-safe, provider-neutral knowledge foundation used
--   by Nandi for document-backed retrieval and future RAG capabilities.
--
-- Architecture:
--   Knowledge Source
--       -> Knowledge Document
--       -> Knowledge Chunk
--       -> Knowledge Embedding
--       -> Future Retrieval Adapter
--       -> Nandi
--       -> Context Package
--
-- Dependencies:
--   065_nandi_ai_provider_foundation.sql
--   066_nandi_ai_model_foundation.sql
--   067_nandi_model_selection_foundation.sql
--   Existing organization / actor foundations
--
-- Important:
--   - Memory is intentionally separate from Knowledge.
--   - No credentials, API keys, or secrets are stored here.
--   - No provider-specific embedding implementation is required.
--   - PostgreSQL vector/pgvector is intentionally NOT required by this
--     foundation migration.
--   - Retrieval execution remains an Nandi/control-plane responsibility.
--
-- PostgreSQL : 17+
-- =============================================================================

BEGIN;

-- =============================================================================
-- Knowledge Source Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n
          ON n.oid = t.typnamespace
        WHERE n.nspname = 'raamaesha'
          AND t.typname = 'knowledge_source_status'
    ) THEN
        CREATE TYPE raamaesha.knowledge_source_status AS ENUM (
            'draft',
            'active',
            'disabled',
            'archived'
        );
    END IF;
END
$$;

-- =============================================================================
-- Knowledge Document Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n
          ON n.oid = t.typnamespace
        WHERE n.nspname = 'raamaesha'
          AND t.typname = 'knowledge_document_status'
    ) THEN
        CREATE TYPE raamaesha.knowledge_document_status AS ENUM (
            'draft',
            'active',
            'processing',
            'failed',
            'archived'
        );
    END IF;
END
$$;

-- =============================================================================
-- Knowledge Chunk Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n
          ON n.oid = t.typnamespace
        WHERE n.nspname = 'raamaesha'
          AND t.typname = 'knowledge_chunk_status'
    ) THEN
        CREATE TYPE raamaesha.knowledge_chunk_status AS ENUM (
            'draft',
            'active',
            'processing',
            'failed',
            'archived'
        );
    END IF;
END
$$;

-- =============================================================================
-- Knowledge Embedding Status
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type t
        JOIN pg_namespace n
          ON n.oid = t.typnamespace
        WHERE n.nspname = 'raamaesha'
          AND t.typname = 'knowledge_embedding_status'
    ) THEN
        CREATE TYPE raamaesha.knowledge_embedding_status AS ENUM (
            'pending',
            'processing',
            'active',
            'failed',
            'superseded'
        );
    END IF;
END
$$;

-- =============================================================================
-- Knowledge Sources
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.knowledge_sources (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,

    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,

    source_type TEXT NOT NULL,
    source_uri TEXT,

    status raamaesha.knowledge_source_status NOT NULL
        DEFAULT 'draft',

    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,

    created_by UUID,
    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_knowledge_sources
        PRIMARY KEY (id),

    CONSTRAINT uq_knowledge_sources_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT fk_knowledge_sources_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_knowledge_sources_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_knowledge_sources_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_knowledge_sources_code_nonblank
        CHECK (btrim(code) <> ''),

    CONSTRAINT chk_knowledge_sources_name_nonblank
        CHECK (btrim(name) <> ''),

    CONSTRAINT chk_knowledge_sources_source_type_nonblank
        CHECK (btrim(source_type) <> ''),

    CONSTRAINT chk_knowledge_sources_source_uri_nonblank
        CHECK (
            source_uri IS NULL
            OR btrim(source_uri) <> ''
        ),

    CONSTRAINT chk_knowledge_sources_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);

-- =============================================================================
-- Knowledge Documents
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.knowledge_documents (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,

    source_id UUID NOT NULL,

    external_document_id TEXT,

    title TEXT NOT NULL,
    document_type TEXT,
    mime_type TEXT,
    source_uri TEXT,

    content_hash TEXT,
    version INTEGER NOT NULL DEFAULT 1,

    status raamaesha.knowledge_document_status NOT NULL
        DEFAULT 'draft',

    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,

    created_by UUID,
    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_knowledge_documents
        PRIMARY KEY (id),

    CONSTRAINT uq_knowledge_documents_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT fk_knowledge_documents_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_knowledge_documents_source
        FOREIGN KEY (source_id, organization_id)
        REFERENCES raamaesha.knowledge_sources(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_knowledge_documents_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_knowledge_documents_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_knowledge_documents_title_nonblank
        CHECK (btrim(title) <> ''),

    CONSTRAINT chk_knowledge_documents_external_id_nonblank
        CHECK (
            external_document_id IS NULL
            OR btrim(external_document_id) <> ''
        ),

    CONSTRAINT chk_knowledge_documents_document_type_nonblank
        CHECK (
            document_type IS NULL
            OR btrim(document_type) <> ''
        ),

    CONSTRAINT chk_knowledge_documents_mime_type_nonblank
        CHECK (
            mime_type IS NULL
            OR btrim(mime_type) <> ''
        ),

    CONSTRAINT chk_knowledge_documents_source_uri_nonblank
        CHECK (
            source_uri IS NULL
            OR btrim(source_uri) <> ''
        ),

    CONSTRAINT chk_knowledge_documents_content_hash_nonblank
        CHECK (
            content_hash IS NULL
            OR btrim(content_hash) <> ''
        ),

    CONSTRAINT chk_knowledge_documents_version_positive
        CHECK (version > 0),

    CONSTRAINT chk_knowledge_documents_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);

-- =============================================================================
-- Knowledge Chunks
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.knowledge_chunks (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,

    document_id UUID NOT NULL,

    chunk_index INTEGER NOT NULL,

    content TEXT NOT NULL,
    content_hash TEXT,

    character_count INTEGER,
    token_count INTEGER,

    status raamaesha.knowledge_chunk_status NOT NULL
        DEFAULT 'draft',

    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,

    created_by UUID,
    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_knowledge_chunks
        PRIMARY KEY (id),

    CONSTRAINT uq_knowledge_chunks_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT uq_knowledge_chunks_document_index
        UNIQUE (document_id, chunk_index),

    CONSTRAINT fk_knowledge_chunks_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_knowledge_chunks_document
        FOREIGN KEY (document_id, organization_id)
        REFERENCES raamaesha.knowledge_documents(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_knowledge_chunks_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_knowledge_chunks_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_knowledge_chunks_index_nonnegative
        CHECK (chunk_index >= 0),

    CONSTRAINT chk_knowledge_chunks_content_nonblank
        CHECK (btrim(content) <> ''),

    CONSTRAINT chk_knowledge_chunks_content_hash_nonblank
        CHECK (
            content_hash IS NULL
            OR btrim(content_hash) <> ''
        ),

    CONSTRAINT chk_knowledge_chunks_character_count_valid
        CHECK (
            character_count IS NULL
            OR character_count >= 0
        ),

    CONSTRAINT chk_knowledge_chunks_token_count_valid
        CHECK (
            token_count IS NULL
            OR token_count >= 0
        ),

    CONSTRAINT chk_knowledge_chunks_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);

-- =============================================================================
-- Knowledge Embeddings
--
-- Provider-neutral foundation.
-- The actual vector representation/index is deliberately implementation-specific
-- and is not required by this migration.
-- =============================================================================

CREATE TABLE IF NOT EXISTS raamaesha.knowledge_embeddings (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL,

    chunk_id UUID NOT NULL,
    model_id UUID NOT NULL,

    embedding_provider_key TEXT,

    embedding_dimension INTEGER,

    status raamaesha.knowledge_embedding_status NOT NULL
        DEFAULT 'pending',

    embedding_reference TEXT,

    metadata JSONB NOT NULL DEFAULT '{}'::JSONB,

    created_by UUID,
    updated_by UUID,

    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMPTZ,

    CONSTRAINT pk_knowledge_embeddings
        PRIMARY KEY (id),

    CONSTRAINT uq_knowledge_embeddings_id_organization
        UNIQUE (id, organization_id),

    CONSTRAINT fk_knowledge_embeddings_organization
        FOREIGN KEY (organization_id)
        REFERENCES raamaesha.organizations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_knowledge_embeddings_chunk
        FOREIGN KEY (chunk_id, organization_id)
        REFERENCES raamaesha.knowledge_chunks(id, organization_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_knowledge_embeddings_model
        FOREIGN KEY (model_id)
        REFERENCES raamaesha.ai_models(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_knowledge_embeddings_created_by
        FOREIGN KEY (created_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_knowledge_embeddings_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES raamaesha.actors(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_knowledge_embeddings_provider_key_nonblank
        CHECK (
            embedding_provider_key IS NULL
            OR btrim(embedding_provider_key) <> ''
        ),

    CONSTRAINT chk_knowledge_embeddings_dimension_positive
        CHECK (
            embedding_dimension IS NULL
            OR embedding_dimension > 0
        ),

    CONSTRAINT chk_knowledge_embeddings_reference_nonblank
        CHECK (
            embedding_reference IS NULL
            OR btrim(embedding_reference) <> ''
        ),

    CONSTRAINT chk_knowledge_embeddings_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);

-- =============================================================================
-- Indexes
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_knowledge_sources_organization_id
    ON raamaesha.knowledge_sources (organization_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_sources_organization_status
    ON raamaesha.knowledge_sources (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_knowledge_sources_source_type
    ON raamaesha.knowledge_sources (organization_id, source_type)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_knowledge_sources_deleted_at
    ON raamaesha.knowledge_sources (deleted_at);

CREATE UNIQUE INDEX IF NOT EXISTS uq_knowledge_sources_active_code
    ON raamaesha.knowledge_sources (organization_id, code)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_knowledge_documents_organization_id
    ON raamaesha.knowledge_documents (organization_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_documents_source_id
    ON raamaesha.knowledge_documents (organization_id, source_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_documents_status
    ON raamaesha.knowledge_documents (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_knowledge_documents_content_hash
    ON raamaesha.knowledge_documents (organization_id, content_hash)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_knowledge_documents_deleted_at
    ON raamaesha.knowledge_documents (deleted_at);

CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_organization_id
    ON raamaesha.knowledge_chunks (organization_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_document_id
    ON raamaesha.knowledge_chunks (organization_id, document_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_status
    ON raamaesha.knowledge_chunks (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_content_hash
    ON raamaesha.knowledge_chunks (organization_id, content_hash)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_deleted_at
    ON raamaesha.knowledge_chunks (deleted_at);

CREATE INDEX IF NOT EXISTS idx_knowledge_embeddings_organization_id
    ON raamaesha.knowledge_embeddings (organization_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_embeddings_chunk_id
    ON raamaesha.knowledge_embeddings (organization_id, chunk_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_embeddings_model_id
    ON raamaesha.knowledge_embeddings (organization_id, model_id);

CREATE INDEX IF NOT EXISTS idx_knowledge_embeddings_status
    ON raamaesha.knowledge_embeddings (organization_id, status)
    WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_knowledge_embeddings_deleted_at
    ON raamaesha.knowledge_embeddings (deleted_at);

-- =============================================================================
-- Updated-at Functions
-- =============================================================================

CREATE OR REPLACE FUNCTION raamaesha.set_knowledge_sources_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION raamaesha.set_knowledge_documents_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION raamaesha.set_knowledge_chunks_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION raamaesha.set_knowledge_embeddings_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

-- =============================================================================
-- Updated-at Triggers
-- =============================================================================

DROP TRIGGER IF EXISTS trg_knowledge_sources_updated_at
    ON raamaesha.knowledge_sources;

CREATE TRIGGER trg_knowledge_sources_updated_at
BEFORE UPDATE ON raamaesha.knowledge_sources
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_knowledge_sources_updated_at();

DROP TRIGGER IF EXISTS trg_knowledge_documents_updated_at
    ON raamaesha.knowledge_documents;

CREATE TRIGGER trg_knowledge_documents_updated_at
BEFORE UPDATE ON raamaesha.knowledge_documents
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_knowledge_documents_updated_at();

DROP TRIGGER IF EXISTS trg_knowledge_chunks_updated_at
    ON raamaesha.knowledge_chunks;

CREATE TRIGGER trg_knowledge_chunks_updated_at
BEFORE UPDATE ON raamaesha.knowledge_chunks
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_knowledge_chunks_updated_at();

DROP TRIGGER IF EXISTS trg_knowledge_embeddings_updated_at
    ON raamaesha.knowledge_embeddings;

CREATE TRIGGER trg_knowledge_embeddings_updated_at
BEFORE UPDATE ON raamaesha.knowledge_embeddings
FOR EACH ROW
EXECUTE FUNCTION raamaesha.set_knowledge_embeddings_updated_at();

-- =============================================================================
-- Documentation
-- =============================================================================

COMMENT ON TABLE raamaesha.knowledge_sources IS
'Tenant-owned origins of knowledge used by Nandi retrieval workflows. Credentials and secrets are intentionally excluded.';

COMMENT ON TABLE raamaesha.knowledge_documents IS
'Logical tenant-owned knowledge documents associated with a knowledge source.';

COMMENT ON TABLE raamaesha.knowledge_chunks IS
'Deterministic retrieval units derived from knowledge documents.';

COMMENT ON TABLE raamaesha.knowledge_embeddings IS
'Provider-neutral embedding records associated with knowledge chunks and centralized AI models. Vector storage and retrieval implementation are intentionally external to this foundation.';

COMMENT ON COLUMN raamaesha.knowledge_embeddings.model_id IS
'References the centralized AI model registry from migration 066. Multiple embedding models may represent the same knowledge chunk.';

COMMENT ON COLUMN raamaesha.knowledge_embeddings.embedding_reference IS
'Implementation-specific reference to embedding storage. The foundation does not require PostgreSQL vector/pgvector.';

COMMIT;
