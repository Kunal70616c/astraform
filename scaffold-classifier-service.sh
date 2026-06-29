#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  AstraForm — Classifier Service scaffold
#  Run from repo root: chmod +x scaffold-classifier-service.sh && ./scaffold-classifier-service.sh
# ─────────────────────────────────────────────────────────────────
set -e

BASE="services/classifier-service"
PKG="$BASE/src/main/java/com/astraform/classifier"
RES="$BASE/src/main/resources"

echo "→ Creating directory structure..."
mkdir -p "$PKG/config" "$PKG/consumer" "$PKG/controller" "$PKG/dto" \
         "$PKG/event" "$PKG/exception" "$PKG/filter" "$PKG/model" \
         "$PKG/repository" "$PKG/service" "$PKG/util"
mkdir -p "$RES/db/migration"
mkdir -p "$BASE/src/test/java/com/astraform/classifier"
rm -f "$BASE/.gitkeep"

# ── pom.xml ──────────────────────────────────────────────────────
cat > "$BASE/pom.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>com.astraform</groupId>
        <artifactId>astraform</artifactId>
        <version>0.0.1-SNAPSHOT</version>
        <relativePath>../../pom.xml</relativePath>
    </parent>

    <artifactId>classifier-service</artifactId>
    <name>AstraForm Classifier Service</name>
    <description>Consumes document events, uses Spring AI to identify form type, publishes classification results</description>

    <dependencies>
        <!-- Web -->
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
        <!-- JPA -->
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-jpa</artifactId></dependency>
        <!-- Security stub -->
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
        <!-- Validation -->
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-validation</artifactId></dependency>
        <!-- Actuator -->
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>
        <!-- RabbitMQ -->
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-amqp</artifactId></dependency>
        <!-- Eureka -->
        <dependency><groupId>org.springframework.cloud</groupId><artifactId>spring-cloud-starter-netflix-eureka-client</artifactId></dependency>
        <!-- PostgreSQL -->
        <dependency><groupId>org.postgresql</groupId><artifactId>postgresql</artifactId><scope>runtime</scope></dependency>
        <!-- Flyway -->
        <dependency><groupId>org.flywaydb</groupId><artifactId>flyway-core</artifactId></dependency>
        <dependency><groupId>org.flywaydb</groupId><artifactId>flyway-database-postgresql</artifactId></dependency>
        <!-- MinIO — same version as document-service -->
        <dependency>
            <groupId>io.minio</groupId>
            <artifactId>minio</artifactId>
            <version>8.5.7</version>
        </dependency>
        <!-- Spring AI — OpenAI -->
        <dependency>
            <groupId>org.springframework.ai</groupId>
            <artifactId>spring-ai-openai-spring-boot-starter</artifactId>
        </dependency>
        <!-- PDFBox — extract text from PDF before sending to AI -->
        <dependency>
            <groupId>org.apache.pdfbox</groupId>
            <artifactId>pdfbox</artifactId>
            <version>3.0.2</version>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
EOF

# ── application.yml ──────────────────────────────────────────────
cat > "$RES/application.yml" << 'EOF'
server:
  port: 8082

spring:
  application:
    name: classifier-service

  datasource:
    url: jdbc:postgresql://localhost:5432/astraform_classifier
    username: astraform
    password: astraform123
    driver-class-name: org.postgresql.Driver

  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: validate
    show-sql: false

  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true

  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest

  ai:
    openai:
      api-key: ${OPENAI_API_KEY:your-openai-api-key-here}
      chat:
        options:
          model: gpt-4o-mini
          temperature: 0.1   # low = deterministic classification

minio:
  endpoint: http://localhost:9000
  access-key: astraform
  secret-key: astraform123
  bucket-name: astraform-documents

eureka:
  client:
    enabled: false

management:
  endpoints:
    web:
      exposure:
        include: health,info

logging:
  level:
    com.astraform: DEBUG
EOF

# ── Flyway migration ──────────────────────────────────────────────
cat > "$RES/db/migration/V1__create_classifications_table.sql" << 'EOF'
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE classifications (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id      UUID         NOT NULL,
    tenant_id        VARCHAR(100) NOT NULL,
    form_type        VARCHAR(100),
    form_name        VARCHAR(255),
    confidence       DECIMAL(5,4),
    description      TEXT,
    status           VARCHAR(50)  NOT NULL DEFAULT 'PENDING',
    failure_reason   TEXT,
    classified_at    TIMESTAMP,
    created_at       TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_classifications_document_id ON classifications (document_id);
CREATE INDEX idx_classifications_tenant_id   ON classifications (tenant_id);
CREATE INDEX idx_classifications_status      ON classifications (status);
EOF

# ── Application entry point ───────────────────────────────────────
cat > "$PKG/ClassifierServiceApplication.java" << 'EOF'
package com.astraform.classifier;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class ClassifierServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(ClassifierServiceApplication.class, args);
    }
}
EOF

# ── Enums ─────────────────────────────────────────────────────────
cat > "$PKG/model/FormType.java" << 'EOF'
package com.astraform.classifier.model;

public enum FormType {
    PAN_APPLICATION,
    AADHAAR_ENROLLMENT,
    DRIVING_LICENSE_APPLICATION,
    PASSPORT_APPLICATION,
    INCOME_TAX_RETURN,
    VISA_APPLICATION,
    BANK_KYC,
    PROPERTY_REGISTRATION,
    VEHICLE_REGISTRATION,
    BIRTH_CERTIFICATE_APPLICATION,
    VOTER_ID_APPLICATION,
    FORM_16,
    GST_RETURN,
    RATION_CARD_APPLICATION,
    UNKNOWN
}
EOF

cat > "$PKG/model/ClassificationStatus.java" << 'EOF'
package com.astraform.classifier.model;

public enum ClassificationStatus {
    PENDING,    // event received, classification in progress
    COMPLETED,  // AI returned a result
    FAILED      // something went wrong
}
EOF

# ── Entity ────────────────────────────────────────────────────────
cat > "$PKG/model/Classification.java" << 'EOF'
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
EOF

# ── Repository ────────────────────────────────────────────────────
cat > "$PKG/repository/ClassificationRepository.java" << 'EOF'
package com.astraform.classifier.repository;

import com.astraform.classifier.model.Classification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ClassificationRepository extends JpaRepository<Classification, UUID> {
    Optional<Classification> findByDocumentId(UUID documentId);
    List<Classification> findByTenantIdOrderByCreatedAtDesc(String tenantId);
}
EOF

# ── DTOs ──────────────────────────────────────────────────────────
cat > "$PKG/dto/ClassificationResult.java" << 'EOF'
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
EOF

cat > "$PKG/dto/ClassificationResponse.java" << 'EOF'
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
EOF

# ── Events ────────────────────────────────────────────────────────
cat > "$PKG/event/DocumentReceivedEvent.java" << 'EOF'
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
EOF

cat > "$PKG/event/DocumentClassifiedEvent.java" << 'EOF'
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
EOF

# ── Util ──────────────────────────────────────────────────────────
cat > "$PKG/util/TenantContext.java" << 'EOF'
package com.astraform.classifier.util;

public class TenantContext {
    private static final ThreadLocal<String> TENANT_ID = new ThreadLocal<>();
    private static final ThreadLocal<String> USER_ID   = new ThreadLocal<>();

    public static void setTenantId(String v) { TENANT_ID.set(v); }
    public static String getTenantId()        { return TENANT_ID.get(); }
    public static void setUserId(String v)    { USER_ID.set(v); }
    public static String getUserId()          { return USER_ID.get(); }
    public static void clear()                { TENANT_ID.remove(); USER_ID.remove(); }
}
EOF

# ── Filter ────────────────────────────────────────────────────────
cat > "$PKG/filter/TenantContextFilter.java" << 'EOF'
package com.astraform.classifier.filter;

import com.astraform.classifier.util.TenantContext;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;

@Component
@Slf4j
public class TenantContextFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        try {
            String tenantId = request.getHeader("X-Tenant-Id");
            String userId   = request.getHeader("X-User-Id");
            TenantContext.setTenantId(tenantId != null ? tenantId : "default");
            TenantContext.setUserId(userId     != null ? userId   : "anonymous");
            chain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }
}
EOF

# ── Config ────────────────────────────────────────────────────────
cat > "$PKG/config/SecurityConfig.java" << 'EOF'
package com.astraform.classifier.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    // MVP: permit all — TODO enable JWT when auth-service is ready
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http.csrf(AbstractHttpConfigurer::disable)
            .authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        return http.build();
    }
}
EOF

cat > "$PKG/config/MinioProperties.java" << 'EOF'
package com.astraform.classifier.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "minio")
@Data
public class MinioProperties {
    private String endpoint;
    private String accessKey;
    private String secretKey;
    private String bucketName;
}
EOF

cat > "$PKG/config/MinioConfig.java" << 'EOF'
package com.astraform.classifier.config;

import io.minio.MinioClient;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@RequiredArgsConstructor
public class MinioConfig {

    private final MinioProperties props;

    @Bean
    public MinioClient minioClient() {
        return MinioClient.builder()
                .endpoint(props.getEndpoint())
                .credentials(props.getAccessKey(), props.getSecretKey())
                .build();
    }
}
EOF

cat > "$PKG/config/RabbitMQConfig.java" << 'EOF'
package com.astraform.classifier.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.config.SimpleRabbitListenerContainerFactory;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE                   = "astraform.exchange";
    public static final String DOCUMENT_RECEIVED_QUEUE   = "document.received.queue";
    public static final String DOCUMENT_CLASSIFIED_KEY   = "document.classified";
    public static final String DOCUMENT_CLASSIFIED_QUEUE = "document.classified.queue";

    @Bean public TopicExchange astraformExchange() {
        return new TopicExchange(EXCHANGE, true, false);
    }

    // This service creates the classified queue for the extraction service to consume
    @Bean public Queue documentClassifiedQueue() {
        return QueueBuilder.durable(DOCUMENT_CLASSIFIED_QUEUE).build();
    }

    @Bean public Binding documentClassifiedBinding(Queue documentClassifiedQueue,
                                                    TopicExchange astraformExchange) {
        return BindingBuilder.bind(documentClassifiedQueue)
                .to(astraformExchange).with(DOCUMENT_CLASSIFIED_KEY);
    }

    @Bean public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean public RabbitTemplate rabbitTemplate(ConnectionFactory cf, MessageConverter converter) {
        RabbitTemplate t = new RabbitTemplate(cf);
        t.setMessageConverter(converter);
        return t;
    }

    // Important: tell the listener container to use JSON converter
    @Bean public SimpleRabbitListenerContainerFactory rabbitListenerContainerFactory(
            ConnectionFactory cf, MessageConverter converter) {
        SimpleRabbitListenerContainerFactory factory = new SimpleRabbitListenerContainerFactory();
        factory.setConnectionFactory(cf);
        factory.setMessageConverter(converter);
        return factory;
    }
}
EOF

cat > "$PKG/config/AiConfig.java" << 'EOF'
package com.astraform.classifier.config;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class AiConfig {

    @Bean
    public ChatClient chatClient(ChatClient.Builder builder) {
        return builder.build();
    }
}
EOF

# ── Services ──────────────────────────────────────────────────────
cat > "$PKG/service/MinioDownloadService.java" << 'EOF'
package com.astraform.classifier.service;

import com.astraform.classifier.config.MinioProperties;
import io.minio.GetObjectArgs;
import io.minio.MinioClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import java.io.InputStream;

@Service
@RequiredArgsConstructor
@Slf4j
public class MinioDownloadService {

    private final MinioClient    minioClient;
    private final MinioProperties props;

    public InputStream downloadFile(String storagePath) {
        try {
            log.debug("Downloading from MinIO: {}", storagePath);
            return minioClient.getObject(GetObjectArgs.builder()
                    .bucket(props.getBucketName())
                    .object(storagePath)
                    .build());
        } catch (Exception e) {
            throw new RuntimeException("Failed to download from MinIO: " + storagePath, e);
        }
    }
}
EOF

cat > "$PKG/service/PdfTextExtractor.java" << 'EOF'
package com.astraform.classifier.service;

import lombok.extern.slf4j.Slf4j;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.stereotype.Service;
import java.io.InputStream;

@Service
@Slf4j
public class PdfTextExtractor {

    public String extractText(InputStream pdfStream) {
        try (PDDocument document = Loader.loadPDF(pdfStream.readAllBytes())) {
            PDFTextStripper stripper = new PDFTextStripper();
            String text = stripper.getText(document);
            log.debug("Extracted {} characters from PDF", text.length());
            return text;
        } catch (Exception e) {
            log.error("PDF text extraction failed", e);
            return "";
        }
    }
}
EOF

cat > "$PKG/service/AiClassifierService.java" << 'EOF'
package com.astraform.classifier.service;

import com.astraform.classifier.dto.ClassificationResult;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class AiClassifierService {

    private final ChatClient   chatClient;
    private final ObjectMapper objectMapper;

    private static final String PROMPT_TEMPLATE = """
            You are a document classification expert specializing in Indian government forms and official documents.

            Analyze the following text extracted from a PDF and identify what type of document or form it is.

            Respond with ONLY a valid JSON object — no markdown, no explanation, no extra text:
            {
              "formType": "FORM_TYPE_CODE",
              "formName": "Human readable name",
              "confidence": 0.95,
              "description": "One sentence describing what this form is for"
            }

            Valid formType values (pick the best match):
            PAN_APPLICATION, AADHAAR_ENROLLMENT, DRIVING_LICENSE_APPLICATION,
            PASSPORT_APPLICATION, INCOME_TAX_RETURN, VISA_APPLICATION, BANK_KYC,
            PROPERTY_REGISTRATION, VEHICLE_REGISTRATION, BIRTH_CERTIFICATE_APPLICATION,
            VOTER_ID_APPLICATION, FORM_16, GST_RETURN, RATION_CARD_APPLICATION, UNKNOWN

            Use UNKNOWN only if you truly cannot determine the document type.

            Document text:
            %s
            """;

    public ClassificationResult classify(String extractedText) {
        // Limit to 3000 chars to stay within token budget
        String text = extractedText.length() > 3000
                ? extractedText.substring(0, 3000) : extractedText;

        try {
            String response = chatClient.prompt()
                    .user(PROMPT_TEMPLATE.formatted(text))
                    .call()
                    .content();

            log.debug("AI classification response: {}", response);
            return objectMapper.readValue(response, ClassificationResult.class);

        } catch (Exception e) {
            log.error("AI classification failed, returning UNKNOWN", e);
            return ClassificationResult.builder()
                    .formType("UNKNOWN")
                    .formName("Unknown Document")
                    .confidence(0.0)
                    .description("Could not classify — AI error")
                    .build();
        }
    }
}
EOF

cat > "$PKG/service/ClassifierService.java" << 'EOF'
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
EOF

# ── Consumer ──────────────────────────────────────────────────────
cat > "$PKG/consumer/DocumentEventConsumer.java" << 'EOF'
package com.astraform.classifier.consumer;

import com.astraform.classifier.event.DocumentReceivedEvent;
import com.astraform.classifier.service.ClassifierService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
@Slf4j
public class DocumentEventConsumer {

    private final ClassifierService classifierService;

    @RabbitListener(queues = "#{T(com.astraform.classifier.config.RabbitMQConfig).DOCUMENT_RECEIVED_QUEUE}")
    public void onDocumentReceived(DocumentReceivedEvent event) {
        log.info("Consumed document.received event for documentId={}", event.getDocumentId());
        classifierService.classifyDocument(event);
    }
}
EOF

# ── Controller ────────────────────────────────────────────────────
cat > "$PKG/controller/ClassificationController.java" << 'EOF'
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
EOF

# ── Exceptions ────────────────────────────────────────────────────
cat > "$PKG/exception/ClassificationException.java" << 'EOF'
package com.astraform.classifier.exception;

public class ClassificationException extends RuntimeException {
    public ClassificationException(String message, Throwable cause) {
        super(message, cause);
    }
}
EOF

cat > "$PKG/exception/GlobalExceptionHandler.java" << 'EOF'
package com.astraform.classifier.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.Map;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> general(Exception ex) {
        log.error("Unhandled exception", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of(
                "error",     "An unexpected error occurred",
                "status",    500,
                "timestamp", LocalDateTime.now().toString()));
    }
}
EOF

# ── Dockerfile ────────────────────────────────────────────────────
cat > "$BASE/Dockerfile" << 'EOF'
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY target/classifier-service-*.jar app.jar
EXPOSE 8082
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

# ── Commit and push ───────────────────────────────────────────────
git add .
git commit -m "feat(classifier-service): scaffold complete service

- Consumes document.received from RabbitMQ
- Downloads PDF from MinIO, extracts text via PDFBox
- Spring AI (OpenAI gpt-4o-mini) classifies form type
- Persists classification to PostgreSQL
- Publishes document.classified event for extraction service
- REST endpoint to poll classification status"

git push origin dev

echo ""
echo "✅  Classifier Service scaffolded and pushed!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Before running — add your OpenAI API key:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Option A — environment variable (recommended):"
echo "    export OPENAI_API_KEY=sk-..."
echo "    mvn spring-boot:run"
echo ""
echo "  Option B — edit application.yml directly (dev only):"
echo "    spring.ai.openai.api-key: sk-..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Run the service:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  cd services/classifier-service"
echo "  mvn spring-boot:run"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test flow:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Upload a PDF via document-service (port 8081)"
echo "  2. Classifier-service auto-consumes the event"
echo "  3. Poll result:"
echo "     GET http://localhost:8082/api/v1/classifications/{documentId}"
echo "     Header: X-Tenant-Id: tenant-001"
echo ""
