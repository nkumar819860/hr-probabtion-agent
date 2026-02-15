employee-onboarding-agent/
├── docker-compose.yml
├── postgres/
│   └── init.sql
├── postgres-mcp/
│   ├── pom.xml
│   ├── src/main/mule/postgres-mcp.xml
│   └── src/main/resources/config.yml
├── agent-network/
│   ├── agent-network.yaml
│   └── exchange.json
├── flex-gateway/
│   └── config.yml
└── README.md


docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: hrdb
      POSTGRES_USER: hruser
      POSTGRES_PASSWORD: hrpass123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U hruser hrdb"]
      interval: 10s
      timeout: 5s
      retries: 5

  mule-mcp:
    build: ./postgres-mcp
    ports:
      - "8081:8081"
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: hrdb
      POSTGRES_USER: hruser
      POSTGRES_PASSWORD: hrpass123
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - ./logs:/opt/mule/logs

  agent-broker:
    image: mulesoft/agent-broker:latest
    ports:
      - "8082:8080"
    environment:
      AGENT_NETWORK_CONFIG: /config/agent-network.yaml
      POSTGRES_MCP_URL: http://mule-mcp:8081/mcp
      SLACK_MCP_URL: http://mule-mcp:8081/slack
    volumes:
      - ./agent-network:/config
      - ./logs:/logs
    depends_on:
      - mule-mcp

  flex-gateway:
    image: mulesoft/flex-gateway:latest
    ports:
      - "8080:8080"
    volumes:
      - ./flex-gateway/config.yml:/usr/local/share/flex-gateway/conf/config.yml
      - ./agent-network:/agents
    command: >
      flex-gateway start
      --config /usr/local/share/flex-gateway/conf/config.yml
      --proxies-dir /agents

volumes:
  postgres_data:

postgres/init.sql

-- HR Tables
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    employee_id VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    department VARCHAR(100),
    role VARCHAR(100),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE it_provisioning (
    id SERIAL PRIMARY KEY,
    employee_id VARCHAR(50) REFERENCES employees(employee_id),
    okta_user_id VARCHAR(100),
    laptop_assigned BOOLEAN DEFAULT FALSE,
    office365_setup BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- MCP Functions
CREATE OR REPLACE FUNCTION onboard_employee(
    p_employee_id VARCHAR, 
    p_first_name VARCHAR, 
    p_last_name VARCHAR, 
    p_email VARCHAR, 
    p_dept VARCHAR, 
    p_role VARCHAR
) RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    -- Insert employee
    INSERT INTO employees (employee_id, first_name, last_name, email, department, role)
    VALUES (p_employee_id, p_first_name, p_last_name, p_email, p_dept, p_role);
    
    -- Create IT provisioning record
    INSERT INTO it_provisioning (employee_id) VALUES (p_employee_id);
    
    SELECT json_build_object(
        'status', 'success',
        'employee_id', p_employee_id,
        'message', 'Employee onboarded successfully',
        'email', p_email,
        'department', p_dept
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_employee(p_employee_id VARCHAR) RETURNS JSON AS $$
BEGIN
    RETURN (
        SELECT json_build_object(
            'employee_id', e.employee_id,
            'name', e.first_name || ' ' || e.last_name,
            'email', e.email,
            'department', e.department,
            'it_provisioned', CASE WHEN i.id IS NOT NULL THEN true ELSE false END
        )
        FROM employees e
        LEFT JOIN it_provisioning i ON e.employee_id = i.employee_id
        WHERE e.employee_id = p_employee_id
    );
END;
$$ LANGUAGE plpgsql;


pom.xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <groupId>com.example</groupId>
    <artifactId>postgres-mcp-server</artifactId>
    <version>1.0.0</version>
    <packaging>mule-application</packaging>
    
    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <mule.maven.plugin.version>4.1.3</mule.maven.plugin.version>
        <mule.version>4.6.0</mule.version>
    </properties>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.mule.tools.maven</groupId>
                <artifactId>mule-maven-plugin</artifactId>
                <version>${mule.maven.plugin.version}</version>
                <extensions>true</extensions>
                <configuration>
                    <classifier>worker</classifier>
                </configuration>
            </plugin>
        </plugins>
    </build>
    
    <dependencies>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <version>42.7.3</version>
        </dependency>
        <!-- Mule Dependencies -->
        <dependency>
            <groupId>com.mulesoft.muleesb</groupId>
            <artifactId>mule-ee-distribution-standalone</artifactId>
            <version>${mule.version}</version>
            <classifier>worker</classifier>
            <type>mule-application</type>
            <scope>provided</scope>
        </dependency>
    </dependencies>
</project>


postgres-mcp/src/main/mule/postgres-mcp.xml

<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:db="http://www.mulesoft.org/schema/mule/db"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns="http://www.mulesoft.org/schema/mule/core" 
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
      http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
      http://www.mulesoft.org/schema/mule/db http://www.mulesoft.org/schema/mule/db/current/mule-db.xsd
      http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <db:config name="postgres_config">
        <db:generic-connection 
            host="${postgres.host}" 
            port="${postgres.port}"
            user="${postgres.username}" 
            password="${postgres.password}"
            database="${postgres.database}"
            driverClassName="org.postgresql.Driver">
            <db:pooling-profile maxIdle="10" maxWait="30000"/>
        </db:generic-connection>
    </db:config>

    <flow name="postgres-mcp-endpoint">
        <http:listener config-ref="HTTP_Listener_config" path="/mcp" doc:name="MCP Listener"/>
        
        <ee:transform doc:name="Parse MCP Request">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    tool: payload.body.tool,
    params: payload.body.params
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        
        <choice doc:name="Route by Tool">
            <when expression="#[payload.tool == 'onboard_employee']">
                <db:execute doc:name="Onboard Employee">
                    <db:statement><![CDATA[SELECT onboard_employee(
                        $[0]::varchar, $[1]::varchar, $[2]::varchar, 
                        $[3]::varchar, $[4]::varchar, $[5]::varchar
                    )]]></db:statement>
                    <db:input-parameters>#[{
                        employee_id: payload.params.employee_id,
                        first_name: payload.params.first_name,
                        last_name: payload.params.last_name,
                        email: payload.params.email,
                        department: payload.params.department,
                        role: payload.params.role
                    }]</db:input-parameters>
                </db:execute>
            </when>
            <when expression="#[payload.tool == 'get_employee']">
                <db:execute doc:name="Get Employee">
                    <db:statement><![CDATA[SELECT get_employee($[0]::varchar)]]></db:statement>
                    <db:input-parameters>#[ [payload.params.employee_id] ]</db:input-parameters>
                </db:execute>
            </when>
            <otherwise>
                <set-payload value="#[output application/json --- { error: 'Unknown tool: ' ++ payload.tool }]" />
            </otherwise>
        </choice>
        
        <ee:transform doc:name="Format MCP Response">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    content: [{
        type: "text",
        text: if (payload.result[0]?) payload.result[0] else payload
    }]
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        
        <http:response-status code="200"/>
        <logger level="INFO" message="#[payload]"/>
    </flow>

    <http:listener-config name="HTTP_Listener_config">
        <http:listener-connection host="0.0.0.0" port="8081"/>
        <http:cors-config ref="CORS_Policy"/>
    </http:listener-config>
    
    <http:cors-config name="CORS_Policy" allowCredentials="true">
        <http:allowed-origins>
            <http:origin>*</http:origin>
        </http:allowed-origins>
        <http:allowed-methods>
            <http:method>GET</http:method>
            <http:method>POST</http:method>
            <http:method>PUT</http:method>
        </http:allowed-methods>
    </http:cors-config>
</mule>
agent-network/agent-network.yaml

apiVersion: a2a.mulesoft.com/v1alpha1
kind: AgentNetwork
metadata:
  name: employee-onboarding-postgres
spec:
  brokers:
    onboarding-broker:
      card:
        protocolVersion: "0.3.0"
        name: "Employee Onboarding Agent (Postgres)"
        description: "Complete employee onboarding workflow using PostgreSQL"
        url: "http://localhost:8080/onboarding-broker"
        provider: 
          organization: "LocalDev"
        defaultInputModes: ["application/json", "text/plain"]
        skills:
          - id: "employee-onboarding"
            description: "Onboards new employees to Postgres HR system"
            tags: ["hr", "onboarding", "postgres"]
      spec:
        llm:
          provider: "openai"
          model: "gpt-4o-mini"
        instructions: |
          You are Employee Onboarding Agent. Process requests like:
          "Onboard John Doe, john.doe@company.com, Software Engineer, Engineering"
          
          Steps:
          1. Extract: Generate employee_id (EMP001 format), name, email, dept, role
          2. Validate: Email format, required fields
          3. Call postgres-mcp.onboard_employee function
          4. Return success confirmation with employee_id
          
          Always respond with JSON: {"status": "success", "employee_id": "..."}
        links:
          - mcp:
              ref: "postgres-mcp"
        maxNumberOfLoops: 10
        maxTokens: 2000
  mcpServers:
    postgres-mcp:
      servers:
        - name: "postgres-hr-mcp"
          url: "http://mule-mcp:8081/mcp"
          transport: "streamableHttp"


flexgateway/config.yml
env:
  http:
    port: 8080
proxies:
  onboarding-broker:
    pathPrefix: /onboarding-broker
    upstreamUrl: http://agent-broker:8080
    policies:
      - rate-limit:
          interval: 1m
          requestsPermitted: 100
      - cors:
          allowedOrigins: ["*"]

Execute

# Clone/create project folder
mkdir employee-onboarding-agent && cd employee-onboarding-agent

# Copy all files above into correct folders

# Start entire stack
docker-compose up --build

# Wait for startup (2-3 mins)


Test

# Test onboarding
curl -X POST http://localhost:8080/onboarding-broker/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{
      "role": "user",
      "content": "Onboard John Doe, john.doe@company.com, Software Engineer, Engineering"
    }]
  }'

# Check Postgres data
docker exec -it employee-onboarding-agent-postgres-1 psql -U hruser -d hrdb -c "SELECT * FROM employees;"


Flow

User Request → Flex Gateway → Agent Broker → Postgres MCP → Database
                           ↓
                       Returns: {"status": "success", "employee_id": "EMP001"}
