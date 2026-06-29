package com.astraform.classifier.dto;

import lombok.*;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ClassificationResult {
    private String formType;
    private String formName;
    private Double confidence;
    private String description;
}
