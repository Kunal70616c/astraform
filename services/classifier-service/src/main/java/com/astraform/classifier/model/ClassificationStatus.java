package com.astraform.classifier.model;

public enum ClassificationStatus {
    PENDING,    // event received, classification in progress
    COMPLETED,  // AI returned a result
    FAILED      // something went wrong
}
