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
