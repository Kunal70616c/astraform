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
