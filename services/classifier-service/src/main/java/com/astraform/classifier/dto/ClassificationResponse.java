package com.astraform.classifier.dto;

import com.astraform.classifier.model.ClassificationStatus;
import com.astraform.classifier.model.FormType;
import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
public class ClassificationResponse {
    private UUID documentId;
    private FormType formType;
    private String formName;
    private Double confidence;
    private String description;
    private ClassificationStatus status;
    private LocalDateTime classifiedAt;
}
