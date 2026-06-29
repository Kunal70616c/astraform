package com.astraform.classifier.event;

import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DocumentClassifiedEvent {
    private UUID          documentId;
    private UUID          classificationId;
    private String        tenantId;
    private String        storagePath;       // extraction service needs this
    private String        originalFileName;
    private String        formType;
    private String        formName;
    private Double        confidence;
    private LocalDateTime classifiedAt;
}
