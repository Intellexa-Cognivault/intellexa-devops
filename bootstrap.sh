#!/bin/bash

echo "🔧 Bootstrapping Intellexa DevOps stack..."

# Load environment variables
if [ -f .env ]; then
  export $(cat .env | xargs)
else
  echo "❗ .env file not found. Please create one based on .env.sample"
  exit 1
fi

# Start Docker Compose stack
docker-compose up -d

echo "✅ DevOps environment started."
