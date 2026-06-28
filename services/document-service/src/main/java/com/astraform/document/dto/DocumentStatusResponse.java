package com.astraform.document.dto;

import com.astraform.document.model.DocumentStatus;
import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class DocumentStatusResponse {
    private UUID           documentId;
    private String         fileName;
    private Long           fileSize;
    private DocumentStatus status;
    private LocalDateTime  uploadedAt;
    private LocalDateTime  updatedAt;
}
