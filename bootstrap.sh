#!/usr/bin/env bash
set -euo pipefail

# Configuration
PROJECT_NAME="intellexa"
POSTGRES_VERSION="15-alpine"
POSTGRES_IMAGE="ankane/pgvector:latest"
REDIS_VERSION="7-alpine"
TIMESCALE_VERSION="2.11.0-pg15"
WEAVIATE_VERSION="latest"
MINIO_VERSION="RELEASE.2023-08-23T10-07-06Z"

# Create Docker network
docker network create ${PROJECT_NAME}-network || true

# Create data directories
mkdir -p ./data/{postgres,minio,weaviate,redis}

# Generate Docker Compose file
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  postgres:
    build:
      context: ./docker/postgres
    container_name: ${PROJECT_NAME}-postgres
    environment:
      POSTGRES_USER: intellexa
      POSTGRES_PASSWORD: intellexa123
      POSTGRES_DB: intellexa
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - ./scripts/init-postgres.sh:/docker-entrypoint-initdb.d/init.sh
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "5432:5432"

  timescale:
    image: timescale/timescaledb:${TIMESCALE_VERSION}
    container_name: ${PROJECT_NAME}-timescale
    environment:
      POSTGRES_USER: timeseries
      POSTGRES_PASSWORD: timeseries123
      POSTGRES_DB: metrics
    volumes:
      - ./scripts/init-timescale.sh:/docker-entrypoint-initdb.d/init.sh
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "5433:5432"

  weaviate:
    image: semitechnologies/weaviate:${WEAVIATE_VERSION}
    container_name: ${PROJECT_NAME}-weaviate
    environment:
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
      QUERY_DEFAULTS_LIMIT: 25
      CLUSTER_HOSTNAME: 'node1'
    volumes:
      - ./data/weaviate:/var/lib/weaviate
      - ./scripts/init-weaviate.json:/etc/weaviate/schema.json
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "8080:8080"
    depends_on:
      - redis

  redis:
    image: redis:${REDIS_VERSION}
    container_name: ${PROJECT_NAME}-redis
    command: redis-server --save 60 1 --loglevel warning
    volumes:
      - ./data/redis:/data
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "6379:6379"

  minio:
    image: minio/minio:${MINIO_VERSION}
    container_name: ${PROJECT_NAME}-minio
    environment:
      MINIO_ROOT_USER: intellexa
      MINIO_ROOT_PASSWORD: intellexa123
    command: server /data --console-address ":9001"
    volumes:
      - ./data/minio:/data
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "9000:9000"
      - "9001:9001"

networks:
  ${PROJECT_NAME}-network:
    driver: bridge
EOF

# Create initialization scripts
mkdir -p ./scripts

# PostgreSQL initialization
cat > ./scripts/init-postgres.sh <<'EOF'
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
EOF

# TimescaleDB initialization
cat > ./scripts/init-timescale.sh <<'EOF'
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS timescaledb;

    CREATE TABLE metrics (
        time TIMESTAMPTZ NOT NULL,
        name TEXT NOT NULL,
        value DOUBLE PRECISION NOT NULL,
        labels JSONB
    );

    SELECT create_hypertable('metrics', 'time');
    CREATE INDEX idx_metrics_name_time ON metrics (name, time DESC);
EOSQL
EOF

# Weaviate schema
cat > ./scripts/init-weaviate.json <<'EOF'
{
  "classes": [{
    "class": "Document",
    "vectorizer": "none",
    "properties": [
      {
        "name": "content",
        "dataType": ["text"]
      },
      {
        "name": "docId",
        "dataType": ["string"]
      },
      {
        "name": "userId",
        "dataType": ["string"]
      }
    ]
  }]
}
EOF

# Set permissions
chmod +x ./scripts/*.sh

# Start containers
docker compose up -d

# Wait for services to initialize
echo "Waiting for databases to initialize (30 seconds)..."
sleep 30

# Initialize MinIO buckets inside the MinIO container to avoid DNS issues
docker exec -it ${PROJECT_NAME}-minio mc alias set local http://localhost:9000 intellexa intellexa123
docker exec -it ${PROJECT_NAME}-minio mc mb local/intellexa-docs --ignore-existing

# Print connection details
echo -e "\n\033[1;32m=== Intellexa Local Development Setup ===\033[0m"
echo "PostgreSQL:"
echo "  Host: localhost:5432"
echo "  Database: intellexa"
echo "  User: intellexa"
echo "  Password: intellexa123"

echo -e "\nTimescaleDB:"
echo "  Host: localhost:5433"
echo "  Database: metrics"
echo "  User: timeseries"
echo "  Password: timeseries123"

echo -e "\nWeaviate:"
echo "  URL: http://localhost:8080"
echo "  No authentication"

echo -e "\nRedis:"
echo "  Host: localhost:6379"
echo "  No password"

echo -e "\nMinIO:"
echo "  Console: http://localhost:9001"
echo "  Access Key: intellexa"
echo "  Secret Key: intellexa123"
echo "  Bucket: intellexa-docs"

echo -e "\n\033[1;32mRun 'docker compose down' to stop services\033[0m"
