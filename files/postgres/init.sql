-- Create simple status enum
CREATE TYPE deployment_status AS ENUM ('running', 'stopped', 'failed');

-- Create simplified deployments table
CREATE TABLE IF NOT EXISTS deployments (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    status deployment_status NOT NULL DEFAULT 'stopped',
    
    -- Container info
    image VARCHAR(255) NOT NULL,
    version VARCHAR(50) NOT NULL,
    
    -- Network config
    host_ip INET,
    port INTEGER,
    
    -- Port forwarding (simple JSON array of port mappings)
    port_forwards JSONB DEFAULT '[]',
    
    -- Basic metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_port CHECK (port BETWEEN 1 AND 65535)
);

-- Add sample PostgreSQL entry
INSERT INTO deployments (
    name,
    description,
    status,
    image,
    version,
    host_ip,
    port,
    port_forwards
) VALUES (
    'postgres-main',
    'Primary PostgreSQL database',
    'running',
    'postgres',
    '15.3',
    '10.0.1.100',
    5432,
    '[
        {"internal": 5432, "external": 5432},
        {"internal": 9187, "external": 9187}
    ]'
);