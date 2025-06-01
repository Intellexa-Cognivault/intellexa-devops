#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Bootstrapping Intellexa DevOps stack..."

# --------------------------------------------------
# Environment Configuration
# --------------------------------------------------
if [ -f .env ]; then
  echo "✅ Using existing .env file"
  export $(grep -v '^#' .env | xargs)
else
  echo "❗ .env file not found."
  echo "Please create a .env file based on the .env.sample file with your secrets."
  exit 1
fi

# Load environment variables
export $(cat .env | xargs)

# --------------------------------------------------
# Infrastructure Setup
# --------------------------------------------------
echo "🚀 Initializing infrastructure..."

# Create data directories
mkdir -p ./data/{postgres,minio,weaviate,redis}

# Create Docker network
docker network create ${PROJECT_NAME}-network 2>/dev/null || true

# Generate Docker Compose file
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  postgres:
    image: postgres:\${POSTGRES_VERSION}
    environment:
      POSTGRES_USER: \${POSTGRES_USER}
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - ./scripts/init-postgres.sh:/docker-entrypoint-initdb.d/init.sh
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "5432:5432"

  timescale:
    image: timescale/timescaledb:\${TIMESCALE_VERSION}
    environment:
      POSTGRES_USER: \${TIMESCALE_USER}
      POSTGRES_PASSWORD: \${TIMESCALE_PASSWORD}
      POSTGRES_DB: metrics
    volumes:
      - ./scripts/init-timescale.sh:/docker-entrypoint-initdb.d/init.sh
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "5433:5432"

  weaviate:
    image: semitechnologies/weaviate:\${WEAVIATE_VERSION}
    environment:
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'true'
      PERSISTENCE_DATA_PATH: '/var/lib/weaviate'
    volumes:
      - ./data/weaviate:/var/lib/weaviate
      - ./scripts/init-weaviate.json:/etc/weaviate/schema.json
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "8080:8080"

  redis:
    image: redis:\${REDIS_VERSION}
    command: redis-server --save 60 1 --loglevel warning
    volumes:
      - ./data/redis:/data
    networks:
      - ${PROJECT_NAME}-network
    ports:
      - "6379:6379"

  minio:
    image: minio/minio:\${MINIO_VERSION}
    environment:
      MINIO_ROOT_USER: \${MINIO_ROOT_USER}
      MINIO_ROOT_PASSWORD: \${MINIO_ROOT_PASSWORD}
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

# --------------------------------------------------
# Schema Initialization
# --------------------------------------------------
echo "📝 Generating schema initialization scripts..."

mkdir -p ./scripts

# PostgreSQL schema
cat > ./scripts/init-postgres.sh <<EOF
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "\$POSTGRES_DB" <<-EOSQL
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
EOF

# TimescaleDB schema
cat > ./scripts/init-timescale.sh <<EOF
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" --dbname "metrics" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS timescaledb;
    
    CREATE TABLE IF NOT EXISTS request_metrics (
        time TIMESTAMPTZ NOT NULL,
        endpoint TEXT NOT NULL,
        duration_ms REAL NOT NULL,
        status_code INT NOT NULL
    );
    
    SELECT create_hypertable('request_metrics', 'time');
EOSQL
EOF

# Weaviate schema
cat > ./scripts/init-weaviate.json <<EOF
{
  "classes": [{
    "class": "DocumentChunk",
    "vectorizer": "none",
    "properties": [
      {"name": "content", "dataType": ["text"]},
      {"name": "docId", "dataType": ["string"]},
      {"name": "chunkIndex", "dataType": ["int"]}
    ]
  }]
}
EOF

chmod +x ./scripts/*.sh

# --------------------------------------------------
# Service Startup
# --------------------------------------------------
echo "🚦 Starting containers..."
docker compose up -d

# --------------------------------------------------
# Post-Install Setup
# --------------------------------------------------
echo "⏳ Waiting for services to initialize (20 seconds)..."
sleep 20

echo "📦 Creating MinIO bucket..."
docker run --rm --network ${PROJECT_NAME}-network \
  -e MC_HOST_minio=http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@minio:9000 \
  minio/mc:latest \
  mb minio/intellexa-docs --ignore-existing

# --------------------------------------------------
# Verification
# --------------------------------------------------
echo "🔍 Verifying services:"

services=(
  "postgres:5432"
  "timescale:5432"
  "weaviate:8080"
  "redis:6379"
  "minio:9000"
)

for service in "${services[@]}"; do
  if docker compose exec -T ${service%:*} nc -z localhost ${service#*:}; then
    echo "  ✅ ${service%:*} is healthy"
  else
    echo "  ❌ ${service%:*} failed health check"
  fi
done

# --------------------------------------------------
# Connection Details
# --------------------------------------------------
echo -e "\n🔑 \033[1;32mIntellexa DevOps Stack Ready\033[0m"
echo "-----------------------------------------------"
echo "PostgreSQL:     postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:5432/${POSTGRES_DB}"
echo "TimescaleDB:    postgres://${TIMESCALE_USER}:${TIMESCALE_PASSWORD}@localhost:5433/metrics"
echo "Weaviate:       http://localhost:8080/v1"
echo "Redis:          redis://localhost:6379"
echo "MinIO Console:  http://localhost:9001 (Access: ${MINIO_ROOT_USER}/${MINIO_ROOT_PASSWORD})"
echo "MinIO Bucket:   intellexa-docs"
echo "-----------------------------------------------"
echo "Run \033[1mdocker compose down\033[0m to stop services"
echo "Run \033[1m./bootstrap.sh\033[0m to recreate environment"
echo "-----------------------------------------------"