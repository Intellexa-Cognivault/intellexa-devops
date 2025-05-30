#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pgvector;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS hstore;

    CREATE TABLE users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email TEXT UNIQUE NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE documents (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id),
        title TEXT NOT NULL,
        content TEXT,
        embeddings_id TEXT,
        s3_path TEXT NOT NULL,
        metadata JSONB,
        created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX idx_document_embeddings ON documents USING ivfflat (embeddings_id vector_cosine_ops);
    CREATE INDEX idx_document_search ON documents USING gin (content gin_trgm_ops);
EOSQL
