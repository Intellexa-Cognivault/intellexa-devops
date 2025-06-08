#!/bin/bash
# intellexa-devops/run-services.sh

case "$1" in
  "minimal")
    docker compose -f docker-compose.optimized.yml up -d postgres redis
    ;;
  "ai")
    docker compose -f docker-compose.optimized.yml up -d postgres redis weaviate
    ;;
  "full")
    docker compose -f docker-compose.optimized.yml up -d
    ;;
  *)
    echo "Usage: $0 [minimal|ai|full]"
    exit 1
    ;;
esac

# Show resource usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"