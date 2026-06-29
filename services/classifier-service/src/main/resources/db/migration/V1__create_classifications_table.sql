CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE classifications (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id      UUID         NOT NULL,
    tenant_id        VARCHAR(100) NOT NULL,
    form_type        VARCHAR(100),
    form_name        VARCHAR(255),
    confidence       DECIMAL(5,4),
    description      TEXT,
    status           VARCHAR(50)  NOT NULL DEFAULT 'PENDING',
    failure_reason   TEXT,
    classified_at    TIMESTAMP,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_classifications_document_id ON classifications (document_id);
CREATE INDEX idx_classifications_tenant_id   ON classifications (tenant_id);
CREATE INDEX idx_classifications_status      ON classifications (status);
