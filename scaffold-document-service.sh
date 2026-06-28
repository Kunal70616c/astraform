#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  AstraForm — Document Service scaffold
#  Run from repo root: chmod +x scaffold-document-service.sh && ./scaffold-document-service.sh
# ─────────────────────────────────────────────────────────────────
set -e

BASE="services/document-service"
PKG="$BASE/src/main/java/com/astraform/document"
RES="$BASE/src/main/resources"

echo "→ Creating directory structure..."
mkdir -p "$PKG/config" "$PKG/controller" "$PKG/dto" "$PKG/event" \
         "$PKG/exception" "$PKG/filter" "$PKG/model" \
         "$PKG/repository" "$PKG/service" "$PKG/util"
mkdir -p "$RES/db/migration"
mkdir -p "$BASE/src/test/java/com/astraform/document"
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

    <artifactId>document-service</artifactId>
    <name>AstraForm Document Service</name>
    <description>Receives PDF uploads, stores in MinIO, triggers processing pipeline</description>

    <dependencies>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-jpa</artifactId></dependency>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-validation</artifactId></dependency>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>
        <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-amqp</artifactId></dependency>
        <dependency><groupId>org.springframework.cloud</groupId><artifactId>spring-cloud-starter-netflix-eureka-client</artifactId></dependency>
        <dependency><groupId>org.postgresql</groupId><artifactId>postgresql</artifactId><scope>runtime</scope></dependency>
        <dependency><groupId>org.flywaydb</groupId><artifactId>flyway-core</artifactId></dependency>
        <dependency><groupId>org.flywaydb</groupId><artifactId>flyway-database-postgresql</artifactId></dependency>
        <dependency>
            <groupId>io.minio</groupId>
            <artifactId>minio</artifactId>
            <version>8.5.7</version>
        </dependency>
        <dependency><groupId>com.astraform</groupId><artifactId>astraform-commons</artifactId></dependency>
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
  port: 8081

spring:
  application:
    name: document-service

  datasource:
    url: jdbc:postgresql://localhost:5432/astraform_documents
    username: astraform
    password: astraform123
    driver-class-name: org.postgresql.Driver

  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect

  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true

  rabbitmq:
    host: localhost
    port: 5672
    username: guest
    password: guest

  servlet:
    multipart:
      enabled: true
      max-file-size: 20MB
      max-request-size: 20MB

minio:
  endpoint: http://localhost:9000
  access-key: astraform
  secret-key: astraform123
  bucket-name: astraform-documents

eureka:
  client:
    enabled: false   # flip to true when Eureka server is running

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
cat > "$RES/db/migration/V1__create_documents_table.sql" << 'EOF'
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE documents (
    id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    file_name          VARCHAR(255) NOT NULL,
    original_file_name VARCHAR(255) NOT NULL,
    content_type       VARCHAR(100),
    file_size          BIGINT,
    storage_path       VARCHAR(500) NOT NULL,
    tenant_id          VARCHAR(100) NOT NULL,
    uploaded_by        VARCHAR(100),
    status             VARCHAR(50)  NOT NULL DEFAULT 'RECEIVED',
    uploaded_at        TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at         TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_tenant_id     ON documents (tenant_id);
CREATE INDEX idx_documents_status        ON documents (status);
CREATE INDEX idx_documents_tenant_status ON documents (tenant_id, status);
EOF

# ── DocumentServiceApplication ────────────────────────────────────
cat > "$PKG/DocumentServiceApplication.java" << 'EOF'
package com.astraform.document;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DocumentServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(DocumentServiceApplication.class, args);
    }
}
EOF

# ── Model ─────────────────────────────────────────────────────────
cat > "$PKG/model/DocumentStatus.java" << 'EOF'
package com.astraform.document.model;

public enum DocumentStatus {
    RECEIVED,       // PDF stored — pipeline not yet started
    CLASSIFYING,    // classifier service is identifying the form type
    CLASSIFIED,     // form type confirmed
    EXTRACTING,     // OCR in progress
    EXTRACTED,      // all fields pulled from PDF
    GUIDING,        // AI generating field instructions
    GUIDED,         // guidance ready for the user
    FAILED          // something went wrong
}
EOF

cat > "$PKG/model/Document.java" << 'EOF'
package com.astraform.document.model;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "documents")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Document {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String fileName;

    @Column(nullable = false)
    private String originalFileName;

    private String contentType;
    private Long   fileSize;

    @Column(nullable = false)
    private String storagePath;

    @Column(nullable = false)
    private String tenantId;

    private String uploadedBy;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private DocumentStatus status;

    @Column(nullable = false)
    private LocalDateTime uploadedAt;

    private LocalDateTime updatedAt;

    @PrePersist
    protected void onCreate() {
        uploadedAt = LocalDateTime.now();
        updatedAt  = LocalDateTime.now();
        if (status == null) status = DocumentStatus.RECEIVED;
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
EOF

# ── Repository ────────────────────────────────────────────────────
cat > "$PKG/repository/DocumentRepository.java" << 'EOF'
package com.astraform.document.repository;

import com.astraform.document.model.Document;
import com.astraform.document.model.DocumentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.UUID;

@Repository
public interface DocumentRepository extends JpaRepository<Document, UUID> {
    List<Document> findByTenantIdOrderByUploadedAtDesc(String tenantId);
    List<Document> findByTenantIdAndStatus(String tenantId, DocumentStatus status);
}
EOF

# ── DTOs ──────────────────────────────────────────────────────────
cat > "$PKG/dto/DocumentUploadResponse.java" << 'EOF'
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
EOF

cat > "$PKG/dto/DocumentStatusResponse.java" << 'EOF'
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
EOF

# ── Event ─────────────────────────────────────────────────────────
cat > "$PKG/event/DocumentReceivedEvent.java" << 'EOF'
package com.astraform.document.event;

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

# ── Util ──────────────────────────────────────────────────────────
cat > "$PKG/util/TenantContext.java" << 'EOF'
package com.astraform.document.util;

/**
 * Per-request tenant + user context stored in ThreadLocal.
 *
 * MVP  : set headers manually in Postman (X-Tenant-Id, X-User-Id).
 * Later: API Gateway extracts these from JWT and injects them — zero code change here.
 */
public class TenantContext {

    private static final ThreadLocal<String> TENANT_ID = new ThreadLocal<>();
    private static final ThreadLocal<String> USER_ID   = new ThreadLocal<>();

    public static void setTenantId(String v) { TENANT_ID.set(v); }
    public static String getTenantId()        { return TENANT_ID.get(); }

    public static void setUserId(String v)    { USER_ID.set(v); }
    public static String getUserId()          { return USER_ID.get(); }

    public static void clear() { TENANT_ID.remove(); USER_ID.remove(); }
}
EOF

# ── Filter ────────────────────────────────────────────────────────
cat > "$PKG/filter/TenantContextFilter.java" << 'EOF'
package com.astraform.document.filter;

import com.astraform.document.util.TenantContext;
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
            log.debug("Request tenant={} user={}", TenantContext.getTenantId(), TenantContext.getUserId());
            chain.doFilter(request, response);
        } finally {
            TenantContext.clear(); // always clean — prevents ThreadPool leaks
        }
    }
}
EOF

# ── Config ────────────────────────────────────────────────────────
cat > "$PKG/config/SecurityConfig.java" << 'EOF'
package com.astraform.document.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

    /**
     * MVP: all requests permitted — no JWT yet.
     *
     * TODO — when auth-service is ready:
     *   1. Add spring-boot-starter-oauth2-resource-server to pom
     *   2. Replace permitAll() with .authenticated()
     *   3. Add JWT decoder config pointing to auth-service
     *   TenantContextFilter already reads the headers the gateway will inject. Zero other changes.
     */
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(AbstractHttpConfigurer::disable)
            .authorizeHttpRequests(auth -> auth.anyRequest().permitAll());
        return http.build();
    }
}
EOF

cat > "$PKG/config/MinioProperties.java" << 'EOF'
package com.astraform.document.config;

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
package com.astraform.document.config;

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
package com.astraform.document.config;

import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.ConnectionFactory;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.amqp.support.converter.Jackson2JsonMessageConverter;
import org.springframework.amqp.support.converter.MessageConverter;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitMQConfig {

    public static final String EXCHANGE                = "astraform.exchange";
    public static final String DOCUMENT_RECEIVED_KEY   = "document.received";
    public static final String DOCUMENT_RECEIVED_QUEUE = "document.received.queue";

    @Bean public TopicExchange astraformExchange() {
        return new TopicExchange(EXCHANGE, true, false);
    }

    @Bean public Queue documentReceivedQueue() {
        return QueueBuilder.durable(DOCUMENT_RECEIVED_QUEUE).build();
    }

    @Bean public Binding documentReceivedBinding(Queue documentReceivedQueue,
                                                 TopicExchange astraformExchange) {
        return BindingBuilder.bind(documentReceivedQueue)
                .to(astraformExchange).with(DOCUMENT_RECEIVED_KEY);
    }

    @Bean public MessageConverter jsonMessageConverter() {
        return new Jackson2JsonMessageConverter();
    }

    @Bean public RabbitTemplate rabbitTemplate(ConnectionFactory cf,
                                               MessageConverter converter) {
        RabbitTemplate t = new RabbitTemplate(cf);
        t.setMessageConverter(converter);
        return t;
    }
}
EOF

# ── Services ──────────────────────────────────────────────────────
cat > "$PKG/service/MinioStorageService.java" << 'EOF'
package com.astraform.document.service;

import com.astraform.document.config.MinioProperties;
import io.minio.*;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import java.io.InputStream;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class MinioStorageService {

    private final MinioClient    minioClient;
    private final MinioProperties props;

    @PostConstruct
    public void initBucket() {
        try {
            boolean exists = minioClient.bucketExists(
                    BucketExistsArgs.builder().bucket(props.getBucketName()).build());
            if (!exists) {
                minioClient.makeBucket(
                        MakeBucketArgs.builder().bucket(props.getBucketName()).build());
                log.info("Created MinIO bucket: {}", props.getBucketName());
            }
        } catch (Exception e) {
            throw new RuntimeException("MinIO bucket init failed", e);
        }
    }

    public String uploadFile(String tenantId, UUID documentId,
                             String fileName, InputStream stream,
                             long size, String contentType) {
        String key = "%s/%s/%s".formatted(tenantId, documentId, fileName);
        try {
            minioClient.putObject(PutObjectArgs.builder()
                    .bucket(props.getBucketName()).object(key)
                    .stream(stream, size, -1).contentType(contentType).build());
            log.info("Stored in MinIO: {}", key);
            return key;
        } catch (Exception e) {
            throw new RuntimeException("MinIO upload failed: " + key, e);
        }
    }

    public void deleteFile(String storagePath) {
        try {
            minioClient.removeObject(RemoveObjectArgs.builder()
                    .bucket(props.getBucketName()).object(storagePath).build());
        } catch (Exception e) {
            log.warn("Could not delete from MinIO: {}", storagePath, e);
        }
    }
}
EOF

cat > "$PKG/service/DocumentService.java" << 'EOF'
package com.astraform.document.service;

import com.astraform.document.config.RabbitMQConfig;
import com.astraform.document.dto.DocumentStatusResponse;
import com.astraform.document.dto.DocumentUploadResponse;
import com.astraform.document.event.DocumentReceivedEvent;
import com.astraform.document.exception.DocumentNotFoundException;
import com.astraform.document.exception.InvalidFileTypeException;
import com.astraform.document.model.Document;
import com.astraform.document.model.DocumentStatus;
import com.astraform.document.repository.DocumentRepository;
import com.astraform.document.util.TenantContext;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class DocumentService {

    private final DocumentRepository  documentRepository;
    private final MinioStorageService minioStorageService;
    private final RabbitTemplate      rabbitTemplate;

    public DocumentUploadResponse uploadDocument(MultipartFile file) {
        validatePdf(file);

        String tenantId   = TenantContext.getTenantId();
        String userId     = TenantContext.getUserId();
        UUID   documentId = UUID.randomUUID();

        // 1. Store PDF in MinIO
        String storagePath;
        try {
            storagePath = minioStorageService.uploadFile(
                    tenantId, documentId, file.getOriginalFilename(),
                    file.getInputStream(), file.getSize(), file.getContentType());
        } catch (IOException e) {
            throw new RuntimeException("Could not read uploaded file", e);
        }

        // 2. Save metadata to PostgreSQL
        Document document = Document.builder()
                .id(documentId)
                .fileName(System.currentTimeMillis() + "_" + file.getOriginalFilename())
                .originalFileName(file.getOriginalFilename())
                .contentType(file.getContentType())
                .fileSize(file.getSize())
                .storagePath(storagePath)
                .tenantId(tenantId)
                .uploadedBy(userId)
                .status(DocumentStatus.RECEIVED)
                .build();

        documentRepository.save(document);
        log.info("Document saved id={} tenant={}", documentId, tenantId);

        // 3. Fire event → classifier service picks this up next
        publishReceivedEvent(document);

        return DocumentUploadResponse.builder()
                .documentId(documentId)
                .fileName(file.getOriginalFilename())
                .status(DocumentStatus.RECEIVED.name())
                .message("Document received. Processing will begin shortly.")
                .uploadedAt(document.getUploadedAt())
                .build();
    }

    public DocumentStatusResponse getStatus(UUID documentId) {
        return toResponse(findOwnedDocument(documentId));
    }

    public List<DocumentStatusResponse> listDocuments() {
        return documentRepository
                .findByTenantIdOrderByUploadedAtDesc(TenantContext.getTenantId())
                .stream().map(this::toResponse).toList();
    }

    // ── helpers ───────────────────────────────────────────────────

    private void validatePdf(MultipartFile file) {
        if (file == null || file.isEmpty())
            throw new InvalidFileTypeException("No file provided");
        String ct  = file.getContentType();
        String fn  = file.getOriginalFilename();
        boolean ok = "application/pdf".equals(ct)
                  || (fn != null && fn.toLowerCase().endsWith(".pdf"));
        if (!ok) throw new InvalidFileTypeException(
                "Only PDF files are accepted. Received: " + ct);
    }

    private Document findOwnedDocument(UUID documentId) {
        Document doc = documentRepository.findById(documentId)
                .orElseThrow(() -> new DocumentNotFoundException("Document not found: " + documentId));
        // return 404 for wrong tenant — never leak existence
        if (!doc.getTenantId().equals(TenantContext.getTenantId()))
            throw new DocumentNotFoundException("Document not found: " + documentId);
        return doc;
    }

    private void publishReceivedEvent(Document doc) {
        DocumentReceivedEvent event = DocumentReceivedEvent.builder()
                .documentId(doc.getId()).tenantId(doc.getTenantId())
                .storagePath(doc.getStoragePath())
                .originalFileName(doc.getOriginalFileName())
                .contentType(doc.getContentType())
                .receivedAt(doc.getUploadedAt()).build();

        rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE, RabbitMQConfig.DOCUMENT_RECEIVED_KEY, event);
        log.info("Published document.received for id={}", doc.getId());
    }

    private DocumentStatusResponse toResponse(Document doc) {
        return DocumentStatusResponse.builder()
                .documentId(doc.getId()).fileName(doc.getOriginalFileName())
                .fileSize(doc.getFileSize()).status(doc.getStatus())
                .uploadedAt(doc.getUploadedAt()).updatedAt(doc.getUpdatedAt()).build();
    }
}
EOF

# ── Controller ────────────────────────────────────────────────────
cat > "$PKG/controller/DocumentController.java" << 'EOF'
package com.astraform.document.controller;

import com.astraform.document.dto.DocumentStatusResponse;
import com.astraform.document.dto.DocumentUploadResponse;
import com.astraform.document.service.DocumentService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.*;

@RestController
@RequestMapping("/api/v1/documents")
@RequiredArgsConstructor
@Slf4j
public class DocumentController {

    private final DocumentService documentService;

    /** POST /api/v1/documents
     *  Postman: form-data  key=file  value=<pdf>
     *  Headers: X-Tenant-Id: tenant-001   X-User-Id: user-001  */
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<DocumentUploadResponse> upload(
            @RequestParam("file") MultipartFile file) {
        log.info("Upload: {} ({}b)", file.getOriginalFilename(), file.getSize());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(documentService.uploadDocument(file));
    }

    /** GET /api/v1/documents/{documentId}  — poll processing status */
    @GetMapping("/{documentId}")
    public ResponseEntity<DocumentStatusResponse> getStatus(
            @PathVariable UUID documentId) {
        return ResponseEntity.ok(documentService.getStatus(documentId));
    }

    /** GET /api/v1/documents  — list all docs for current tenant */
    @GetMapping
    public ResponseEntity<List<DocumentStatusResponse>> list() {
        return ResponseEntity.ok(documentService.listDocuments());
    }
}
EOF

# ── Exceptions ────────────────────────────────────────────────────
cat > "$PKG/exception/DocumentNotFoundException.java" << 'EOF'
package com.astraform.document.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.NOT_FOUND)
public class DocumentNotFoundException extends RuntimeException {
    public DocumentNotFoundException(String msg) { super(msg); }
}
EOF

cat > "$PKG/exception/InvalidFileTypeException.java" << 'EOF'
package com.astraform.document.exception;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.ResponseStatus;

@ResponseStatus(HttpStatus.BAD_REQUEST)
public class InvalidFileTypeException extends RuntimeException {
    public InvalidFileTypeException(String msg) { super(msg); }
}
EOF

cat > "$PKG/exception/GlobalExceptionHandler.java" << 'EOF'
package com.astraform.document.exception;

import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.Map;

@RestControllerAdvice
@Slf4j
public class GlobalExceptionHandler {

    @ExceptionHandler(DocumentNotFoundException.class)
    public ResponseEntity<Map<String,Object>> notFound(DocumentNotFoundException ex) {
        return error(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(InvalidFileTypeException.class)
    public ResponseEntity<Map<String,Object>> badFile(InvalidFileTypeException ex) {
        return error(HttpStatus.BAD_REQUEST, ex.getMessage());
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String,Object>> general(Exception ex) {
        log.error("Unhandled exception", ex);
        return error(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
    }

    private ResponseEntity<Map<String,Object>> error(HttpStatus status, String msg) {
        return ResponseEntity.status(status).body(Map.of(
                "error",     msg,
                "status",    status.value(),
                "timestamp", LocalDateTime.now().toString()));
    }
}
EOF

# ── Dockerfile ────────────────────────────────────────────────────
cat > "$BASE/Dockerfile" << 'EOF'
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY target/document-service-*.jar app.jar
EXPOSE 8081
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

# ── Done ──────────────────────────────────────────────────────────
echo ""
echo "✅  Document Service scaffolded!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Start dependencies (MinIO is already running)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  docker run -d -p 5432:5432 --name astraform-postgres \\"
echo "    -e POSTGRES_USER=astraform \\"
echo "    -e POSTGRES_PASSWORD=astraform123 \\"
echo "    -e POSTGRES_DB=astraform_documents \\"
echo "    postgres:15-alpine"
echo ""
echo "  docker run -d -p 5672:5672 -p 15672:15672 \\"
echo "    --name astraform-rabbitmq rabbitmq:3-management"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Run the service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  cd services/document-service"
echo "  mvn spring-boot:run"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test in Postman"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  POST   http://localhost:8081/api/v1/documents"
echo "  Header X-Tenant-Id: tenant-001"
echo "  Header X-User-Id:   user-001"
echo "  Body   form-data → key: file → value: any PDF"
echo ""
echo "  GET    http://localhost:8081/api/v1/documents/{id}"
echo "  GET    http://localhost:8081/api/v1/documents"
echo ""

git add .
git commit -m "feat(document-service): scaffold complete service

- PDF upload endpoint with MinIO storage
- PostgreSQL metadata persistence via Flyway
- RabbitMQ document.received event publisher
- Tenant isolation via X-Tenant-Id header
- Security permit-all stub (JWT TODO comment in place)
- Status polling and document listing endpoints"

git push origin dev
echo "✅  Pushed to dev"
