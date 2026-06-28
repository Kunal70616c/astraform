package com.astraform.document.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class DocumentUploadResponse {
    private UUID          documentId;
    private String        fileName;
    private String        status;
    private String        message;
    private LocalDateTime uploadedAt;
}
