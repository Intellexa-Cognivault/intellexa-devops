#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pgvector;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    
    CREATE TABLE IF NOT EXISTS documents (
        id SERIAL PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT,
        embeddings_vector VECTOR(1536),
        created_at TIMESTAMPTZ DEFAULT NOW()
    );
    
    CREATE INDEX idx_document_embeddings ON documents USING ivfflat (embeddings_vector vector_cosine_ops);
EOSQL
