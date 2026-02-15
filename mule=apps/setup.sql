-- HR Database Schema
CREATE TABLE employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    department VARCHAR(100),
    status VARCHAR(50) DEFAULT 'pending',
    onboarded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE hr_policies (
    id SERIAL PRIMARY KEY,
    policy_name VARCHAR(255) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample Data
INSERT INTO employees (name, email, department, status) VALUES 
('Jane Smith', 'jane@company.com', 'HR', 'active'),
('Mike Johnson', 'mike@company.com', 'Engineering', 'active');

INSERT INTO hr_policies (policy_name, description) VALUES 
('Onboarding Policy', 'All new hires must complete 3-day onboarding'),
('Laptop Assignment', 'Engineers get MacBook Pro M3');

-- Add equipment table
CREATE TABLE employee_equipment (
    id SERIAL PRIMARY KEY,
    employee_id INTEGER REFERENCES employees(id),
    equipment VARCHAR(255),
    status VARCHAR(50) DEFAULT 'assigned',
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX idx_employees_name ON employees(name);
CREATE INDEX idx_employees_department ON employees(department);
CREATE INDEX idx_employees_status ON employees(status);
