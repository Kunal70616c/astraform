CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE documents (
    id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name          VARCHAR(255) NOT NULL,
    original_file_name VARCHAR(255) NOT NULL,
    content_type       VARCHAR(100),
    file_size          BIGINT,
    storage_path       VARCHAR(500) NOT NULL,
    tenant_id          VARCHAR(100) NOT NULL,
    uploaded_by        VARCHAR(100),
    status             VARCHAR(50)  NOT NULL DEFAULT 'RECEIVED',
    uploaded_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_tenant_id     ON documents (tenant_id);
CREATE INDEX idx_documents_status        ON documents (status);
CREATE INDEX idx_documents_tenant_status ON documents (tenant_id, status);
