#!/bin/bash

# Apply Weaviate schema classes individually from init-weaviate.json to running instance

SCHEMA_FILE="scripts/init-weaviate.json"
WEAVIATE_URL="http://localhost:8080/v1/schema"

if ! command -v jq &> /dev/null
then
    echo "jq could not be found, please install jq to run this script."
    exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "Schema file $SCHEMA_FILE not found!"
  exit 1
fi

CLASSES=$(jq -c '.classes[]' "$SCHEMA_FILE")

for CLASS in $CLASSES; do
  CLASS_NAME=$(echo "$CLASS" | jq -r '.class')
  echo "Applying class: $CLASS_NAME"
  RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" -d "$CLASS" "$WEAVIATE_URL")
  echo "Response: $RESPONSE"
done

echo -e "\nVerifying applied schema..."

curl -X GET "http://localhost:8080/v1/schema"

echo -e "\nDone."
