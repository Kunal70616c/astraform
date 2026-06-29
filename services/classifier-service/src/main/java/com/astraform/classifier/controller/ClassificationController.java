package com.astraform.classifier.controller;

import com.astraform.classifier.dto.ClassificationResponse;
import com.astraform.classifier.model.Classification;
import com.astraform.classifier.repository.ClassificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/classifications")
@RequiredArgsConstructor
public class ClassificationController {

    private final ClassificationRepository classificationRepository;

    /** GET /api/v1/classifications/{documentId}  — poll result after upload */
    @GetMapping("/{documentId}")
    public ResponseEntity<ClassificationResponse> getByDocumentId(
            @PathVariable UUID documentId) {
        return classificationRepository.findByDocumentId(documentId)
                .map(this::toResponse)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    private ClassificationResponse toResponse(Classification c) {
        return ClassificationResponse.builder()
                .documentId(c.getDocumentId())
                .formType(c.getFormType())
                .formName(c.getFormName())
                .confidence(c.getConfidence())
                .description(c.getDescription())
                .status(c.getStatus())
                .classifiedAt(c.getClassifiedAt())
                .build();
    }
}
