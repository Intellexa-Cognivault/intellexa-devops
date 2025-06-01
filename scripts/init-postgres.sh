#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create extensions
    CREATE EXTENSION IF NOT EXISTS vector;
    CREATE EXTENSION IF NOT EXISTS pgcrypto;  -- For UUID generation
    
    -- Users Table
    CREATE TABLE users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT NOW()
    );
    
    -- Documents Table
    CREATE TABLE documents (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        description TEXT,
        file_url TEXT NOT NULL, -- S3/MinIO URL
        uploaded_at TIMESTAMP DEFAULT NOW()
    );
    
    -- Chunks Table
    CREATE TABLE chunks (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
        content TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT NOW(),
        CONSTRAINT unique_chunk_per_document UNIQUE (document_id, chunk_index)
    );
    
    -- Embeddings Table
    CREATE TABLE embeddings (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        chunk_id UUID REFERENCES chunks(id) ON DELETE CASCADE,
        embedding vector(1536) NOT NULL, -- OpenAI embedding dimension
        created_at TIMESTAMP DEFAULT NOW()
    );
    
    -- Activity Logs
    CREATE TABLE activity_logs (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id) ON DELETE SET NULL,
        action TEXT NOT NULL,
        metadata JSONB,
        timestamp TIMESTAMP DEFAULT NOW()
    );
    
    -- Indexes for performance
    CREATE INDEX idx_embeddings_vector ON embeddings USING ivfflat (embedding vector_cosine_ops)
        WITH (lists = 100);  -- Adjust based on dataset size
    
    CREATE INDEX idx_activity_user ON activity_logs(user_id);
    CREATE INDEX idx_documents_user ON documents(user_id);
    CREATE INDEX idx_chunks_document ON chunks(document_id);
EOSQL