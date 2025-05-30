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
