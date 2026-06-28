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
