#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Bootstrapping Intellexa stack..."

# Cleanup previous runs
docker compose down -v 2>/dev/null || true
docker network rm intellexa-network 2>/dev/null || true

# Initialize fresh
docker network create intellexa-network || true

# Build with clean cache
docker compose build --no-cache && \
docker compose up -d

# Verify services
success=true
failed_services=()

for service in postgres timescale weaviate redis minio; do
  count=0
  while ! docker compose ps | grep "$service.*running"; do
    if [ $count -ge 10 ]; then
      echo "⚠️ Timeout waiting for $service to start after 10 attempts."
      echo "📝 Showing logs for $service to diagnose the issue:"
      docker compose logs $service --tail=20
      success=false
      failed_services+=("$service")
      break
    fi
    echo "⏳ Waiting for $service to start... ($((count+1))/10)"
    count=$((count+1))
    sleep 5
  done
done

if [ "$success" = true ]; then
  echo "✅ All services running"
else
  echo "❌ Some services failed to start successfully:"
  for failed_service in "${failed_services[@]}"; do
    echo "  - $failed_service"
  done
fi

echo ""
echo "Connection details:"
echo "Postgres: host=localhost port=5432 user=intellexa password=intellexa123 db=intellexa"
echo "Timescale: host=localhost port=5433 user=timeseries password=timeseries123 db=metrics"
echo "Weaviate: http://localhost:8081"
echo "Redis: host=localhost port=6379"
echo "Minio: http://localhost:9000 (user: intellexa, password: intellexa123)"
