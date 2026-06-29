package com.astraform.classifier.event;

import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DocumentReceivedEvent {
    private UUID          documentId;
    private String        tenantId;
    private String        storagePath;
    private String        originalFileName;
    private String        contentType;
    private LocalDateTime receivedAt;
}
