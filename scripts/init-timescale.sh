#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "metrics" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS timescaledb;
    
    CREATE TABLE IF NOT EXISTS request_metrics (
        time TIMESTAMPTZ NOT NULL,
        endpoint TEXT NOT NULL,
        duration_ms REAL NOT NULL,
        status_code INT NOT NULL
    );
    
    SELECT create_hypertable('request_metrics', 'time');
EOSQL
