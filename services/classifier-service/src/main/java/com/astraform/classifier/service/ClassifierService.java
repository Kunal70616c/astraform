package com.astraform.classifier.service;

import com.astraform.classifier.config.RabbitMQConfig;
import com.astraform.classifier.dto.ClassificationResult;
import com.astraform.classifier.event.DocumentClassifiedEvent;
import com.astraform.classifier.event.DocumentReceivedEvent;
import com.astraform.classifier.model.Classification;
import com.astraform.classifier.model.ClassificationStatus;
import com.astraform.classifier.model.FormType;
import com.astraform.classifier.repository.ClassificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.io.InputStream;
import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class ClassifierService {

    private final MinioDownloadService    minioDownloadService;
    private final PdfTextExtractor        pdfTextExtractor;
    private final AiClassifierService     aiClassifierService;
    private final ClassificationRepository classificationRepository;
    private final RabbitTemplate          rabbitTemplate;

    @Transactional
    public void classifyDocument(DocumentReceivedEvent event) {
        log.info("Starting classification for documentId={}", event.getDocumentId());

        Classification classification = Classification.builder()
                .documentId(event.getDocumentId())
                .tenantId(event.getTenantId())
                .status(ClassificationStatus.PENDING)
                .build();

        classification = classificationRepository.save(classification);

        try {
            // 1. Download PDF from MinIO
            InputStream pdfStream = minioDownloadService.downloadFile(event.getStoragePath());

            // 2. Extract text — PDFBox handles most printed PDFs
            String text = pdfTextExtractor.extractText(pdfStream);

            // 3. Fallback: if PDF has no text layer, use filename as hint
            if (text.isBlank()) {
                log.warn("No text extracted from PDF — using filename hint: {}", event.getOriginalFileName());
                text = "Document filename: " + event.getOriginalFileName();
            }

            // 4. Send to AI for classification
            ClassificationResult result = aiClassifierService.classify(text);

            // 5. Parse form type safely
            FormType formType;
            try {
                formType = FormType.valueOf(result.getFormType());
            } catch (IllegalArgumentException e) {
                log.warn("AI returned unknown formType: {} — defaulting to UNKNOWN", result.getFormType());
                formType = FormType.UNKNOWN;
            }

            // 6. Persist result
            classification.setFormType(formType);
            classification.setFormName(result.getFormName());
            classification.setConfidence(result.getConfidence());
            classification.setDescription(result.getDescription());
            classification.setStatus(ClassificationStatus.COMPLETED);
            classification.setClassifiedAt(LocalDateTime.now());
            classification = classificationRepository.save(classification);

            // 7. Publish event → extraction service picks this up next
            publishClassifiedEvent(event, classification);

            log.info("Classified documentId={} as {} (confidence={})",
                    event.getDocumentId(), formType, result.getConfidence());

        } catch (Exception e) {
            log.error("Classification failed for documentId={}", event.getDocumentId(), e);
            classification.setStatus(ClassificationStatus.FAILED);
            classification.setFailureReason(e.getMessage());
            classificationRepository.save(classification);
        }
    }

    private void publishClassifiedEvent(DocumentReceivedEvent received, Classification classification) {
        DocumentClassifiedEvent event = DocumentClassifiedEvent.builder()
                .documentId(received.getDocumentId())
                .classificationId(classification.getId())
                .tenantId(received.getTenantId())
                .storagePath(received.getStoragePath())
                .originalFileName(received.getOriginalFileName())
                .formType(classification.getFormType().name())
                .formName(classification.getFormName())
                .confidence(classification.getConfidence())
                .classifiedAt(classification.getClassifiedAt())
                .build();

        rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE,
                RabbitMQConfig.DOCUMENT_CLASSIFIED_KEY,
                event);

        log.info("Published document.classified for documentId={}", received.getDocumentId());
    }
}
