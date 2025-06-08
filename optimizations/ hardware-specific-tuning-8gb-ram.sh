#!/bin/bash

# Apply these before starting containers
sudo sysctl -w vm.swappiness=10  # Reduce swapping
docker system prune -af  # Clean unused objects

# PostgreSQL config (run after DB starts)
docker compose exec postgres psql -U intellexa -c "
ALTER SYSTEM SET shared_buffers = '128MB';
ALTER SYSTEM SET effective_cache_size = '512MB';
ALTER SYSTEM SET maintenance_work_mem = '32MB';"