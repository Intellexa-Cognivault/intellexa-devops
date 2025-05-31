#!/bin/bash

# Apply Weaviate schema from init-weaviate.json to running instance

SCHEMA_FILE="scripts/init-weaviate.json"
WEAVIATE_URL="http://localhost:8080/v1/schema"

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "Schema file $SCHEMA_FILE not found!"
  exit 1
fi

echo "Applying schema from $SCHEMA_FILE to $WEAVIATE_URL..."

curl -X PUT -H "Content-Type: application/json" --data @"$SCHEMA_FILE" "$WEAVIATE_URL"

echo -e "\n\nVerifying applied schema..."

curl -X GET "$WEAVIATE_URL"

echo -e "\nDone."
