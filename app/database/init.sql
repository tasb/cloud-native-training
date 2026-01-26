CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some sample data
INSERT INTO items (name, description) VALUES
    ('Docker', 'Container runtime for packaging and running applications'),
    ('Kubernetes', 'Container orchestration platform'),
    ('Cloud Native', 'Building and running scalable applications in modern cloud environments');
