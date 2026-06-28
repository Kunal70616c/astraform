package com.astraform.document.service;

import com.astraform.document.config.RabbitMQConfig;
import com.astraform.document.dto.DocumentStatusResponse;
import com.astraform.document.dto.DocumentUploadResponse;
import com.astraform.document.event.DocumentReceivedEvent;
import com.astraform.document.exception.DocumentNotFoundException;
import com.astraform.document.exception.InvalidFileTypeException;
import com.astraform.document.model.Document;
import com.astraform.document.model.DocumentStatus;
import com.astraform.document.repository.DocumentRepository;
import com.astraform.document.util.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DocumentService {

    private final DocumentRepository  documentRepository;
    private final MinioStorageService minioStorageService;
    private final RabbitTemplate      rabbitTemplate;

    public DocumentUploadResponse uploadDocument(MultipartFile file) {
        validatePdf(file);

        String tenantId   = TenantContext.getTenantId();
        String userId     = TenantContext.getUserId();
        UUID   documentId = UUID.randomUUID();

        // 1. Store PDF in MinIO
        String storagePath;
        try {
            storagePath = minioStorageService.uploadFile(
                    tenantId, documentId, file.getOriginalFilename(),
                    file.getInputStream(), file.getSize(), file.getContentType());
        } catch (IOException e) {
            throw new RuntimeException("Could not read uploaded file", e);
        }

        // 2. Save metadata to PostgreSQL
        Document document = Document.builder()
                .id(documentId)
                .fileName(System.currentTimeMillis() + "_" + file.getOriginalFilename())
                .originalFileName(file.getOriginalFilename())
                .contentType(file.getContentType())
                .fileSize(file.getSize())
                .storagePath(storagePath)
                .tenantId(tenantId)
                .uploadedBy(userId)
                .status(DocumentStatus.RECEIVED)
                .build();

        documentRepository.save(document);
        log.info("Document saved id={} tenant={}", documentId, tenantId);

        // 3. Fire event → classifier service picks this up next
        publishReceivedEvent(document);

        return DocumentUploadResponse.builder()
                .documentId(documentId)
                .fileName(file.getOriginalFilename())
                .status(DocumentStatus.RECEIVED.name())
                .message("Document received. Processing will begin shortly.")
                .uploadedAt(document.getUploadedAt())
                .build();
    }

    public DocumentStatusResponse getStatus(UUID documentId) {
        return toResponse(findOwnedDocument(documentId));
    }

    public List<DocumentStatusResponse> listDocuments() {
        return documentRepository
                .findByTenantIdOrderByUploadedAtDesc(TenantContext.getTenantId())
                .stream().map(this::toResponse).toList();
    }

    // ── helpers ───────────────────────────────────────────────────

    private void validatePdf(MultipartFile file) {
        if (file == null || file.isEmpty())
            throw new InvalidFileTypeException("No file provided");
        String ct  = file.getContentType();
        String fn  = file.getOriginalFilename();
        boolean ok = "application/pdf".equals(ct)
                  || (fn != null && fn.toLowerCase().endsWith(".pdf"));
        if (!ok) throw new InvalidFileTypeException(
                "Only PDF files are accepted. Received: " + ct);
    }

    private Document findOwnedDocument(UUID documentId) {
        Document doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new DocumentNotFoundException("Document not found: " + documentId));
        // return 404 for wrong tenant — never leak existence
        if (!doc.getTenantId().equals(TenantContext.getTenantId()))
            throw new DocumentNotFoundException("Document not found: " + documentId);
        return doc;
    }

    private void publishReceivedEvent(Document doc) {
        DocumentReceivedEvent event = DocumentReceivedEvent.builder()
                .documentId(doc.getId()).tenantId(doc.getTenantId())
                .storagePath(doc.getStoragePath())
                .originalFileName(doc.getOriginalFileName())
                .contentType(doc.getContentType())
                .receivedAt(doc.getUploadedAt()).build();

        rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE, RabbitMQConfig.DOCUMENT_RECEIVED_KEY, event);
        log.info("Published document.received for id={}", doc.getId());
    }

    private DocumentStatusResponse toResponse(Document doc) {
        return DocumentStatusResponse.builder()
                .documentId(doc.getId()).fileName(doc.getOriginalFileName())
                .fileSize(doc.getFileSize()).status(doc.getStatus())
                .uploadedAt(doc.getUploadedAt()).updatedAt(doc.getUpdatedAt()).build();
    }
}
