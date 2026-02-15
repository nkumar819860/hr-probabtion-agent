#!/bin/bash
# HR Probation Agent Fabric - Complete Deployment
# ./deploy.sh --groq-key "gsk_xxx"

set -e
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'

GROQ_KEY="$2"
[[ -z "$GROQ_KEY" ]] && { echo -e "${RED}Usage: ./deploy.sh --groq-key gsk_xxx${NC}"; exit 1; }

echo -e "${GREEN}🚀 HR PROBATION AGENT FABRIC - FULL DEPLOYMENT${NC}"

# Create structure
mkdir -p database mule-apps exchange-assets logs

# Start stack
echo -e "${YELLOW}Starting PostgreSQL + APIs...${NC}"
docker-compose up -d postgres-hr employee-api agent-broker
sleep 15

# Test APIs
echo -e "${YELLOW}Testing APIs...${NC}"
curl -s http://localhost:8081/employees | jq > /dev/null && echo -e "${GREEN}✅ Employee API OK${NC}"
curl -s -X POST http://localhost:8083/agent/command -H "Content-Type: application/json" -d '{"message":"test"}' | jq > /dev/null && echo -e "${GREEN}✅ Agent Broker OK${NC}"

# Generate Exchange assets
cat > exchange-assets/employee-api.raml << 'EOF'
#%RAML 1.0
title: HR Employee Master API v1
baseUri: http://localhost:8081
/employees:
  get:
    (get):
      responses:
        200:
          body:
            application/json:
              example: |
                {"success": true, "employees": [...]}
  /{id}:
    get:
      responses:
        200:
          body: application/json
EOF

cat > exchange-assets/agent-broker.raml << 'EOF'
#%RAML 1.0  
title: HR Agent Fabric Broker v1
baseUri: http://localhost:8083
/agent/command:
  post:
    body: application/json
    responses:
      200:
        body: application/json
EOF

echo -e "${GREEN}🎉 FULL STACK LIVE!${NC}"
echo "  🗄️  PostgreSQL: localhost:5432"
echo "  👥  Employee API: http://localhost:8081/employees" 
echo "  🤖  Agent Broker: http://localhost:8083/agent/command"
echo "  📦  Exchange RAML: ./exchange-assets/"
echo ""
echo -e "${YELLOW}TEST COMMANDS:${NC}"
echo "curl http://localhost:8081/employees"
echo 'curl -X POST http://localhost:8083/agent/command -d "{\"message\":\"check probation EMP001\"}"'
echo 'curl -X POST http://localhost:8083/agent/command -d "{\"message\":\"complete probation EMP002\"}"'
