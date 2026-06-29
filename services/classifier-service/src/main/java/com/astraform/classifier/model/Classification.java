package com.astraform.classifier.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "classifications")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Classification {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private UUID documentId;

    @Column(nullable = false)
    private String tenantId;

    @Enumerated(EnumType.STRING)
    private FormType formType;

    private String formName;
    private Double confidence;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private ClassificationStatus status;

    @Column(columnDefinition = "TEXT")
    private String failureReason;

    private LocalDateTime classifiedAt;

    @Column(nullable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        if (status == null) status = ClassificationStatus.PENDING;
    }
}
