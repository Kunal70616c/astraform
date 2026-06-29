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
