package com.astraform.classifier.repository;

import com.astraform.classifier.model.Classification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ClassificationRepository extends JpaRepository<Classification, UUID> {
    Optional<Classification> findByDocumentId(UUID documentId);
    List<Classification> findByTenantIdOrderByCreatedAtDesc(String tenantId);
}
