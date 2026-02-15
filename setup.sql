CREATE TABLE employees (
  id SERIAL PRIMARY KEY,
  employee_id VARCHAR(10) UNIQUE NOT NULL,
  name VARCHAR(100),
  email VARCHAR(100),
  department VARCHAR(50),
  hire_date DATE,
  probation_end DATE,
  probation_status VARCHAR(20) DEFAULT 'ACTIVE',
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO employees (employee_id, name, email, department, hire_date, probation_end, probation_status) VALUES
('EMP001', 'John Doe', 'john@company.com', 'Engineering', '2025-01-15', '2025-07-15', 'ACTIVE'),
('EMP002', 'Jane Smith', 'jane@company.com', 'HR', '2025-02-01', '2025-08-01', 'ACTIVE'),
('EMP003', 'Mike Wilson', 'mike@company.com', 'Finance', '2024-12-01', '2025-06-01', 'COMPLETED');
