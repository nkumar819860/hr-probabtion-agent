#!/bin/bash

echo "🚀 Deploying HR Agent Fabric Demo..."

# Validate environment
if [ ! -f ".env" ]; then
  echo "❌ .env file not found. Copy .env.example to .env and update values."
  exit 1
fi

# Load environment
set -a
source .env
set +a

# Build and start services
echo "📦 Building and starting services..."
docker compose down -v
docker compose build
docker compose up -d

# Wait for database
echo "⏳ Waiting for PostgreSQL..."
sleep 10

# Validate services
echo "✅ Checking service health..."
if docker compose ps | grep -q "healthy"; then
  echo "✅ All services healthy!"
else
  echo "⚠️  Some services still starting..."
fi

# Show endpoints
echo ""
echo "🌐 HR Agent Fabric Endpoints:"
echo "  Broker: http://localhost:8081/hr-agent/onboard"
echo "  MCP Server: http://localhost:8082"
echo "  Database: localhost:5432"
echo ""
echo "📋 Test Commands:"
echo "  curl -X POST http://localhost:8081/hr-agent/onboard \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"name\":\"John Doe\",\"email\":\"john@company.com\",\"department\":\"Engineering\"}'"
echo ""
echo "🎉 HR Agent Fabric deployed successfully!"
