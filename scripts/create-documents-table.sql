dockerCREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    content TEXT,
    docId VARCHAR(255),
    userId VARCHAR(255)
);
