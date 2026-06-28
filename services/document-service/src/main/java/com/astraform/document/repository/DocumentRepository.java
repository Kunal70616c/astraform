package com.astraform.document.repository;

import com.astraform.document.model.Document;
import com.astraform.document.model.DocumentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface DocumentRepository extends JpaRepository<Document, UUID> {
    List<Document> findByTenantIdOrderByUploadedAtDesc(String tenantId);
    List<Document> findByTenantIdAndStatus(String tenantId, DocumentStatus status);
}
