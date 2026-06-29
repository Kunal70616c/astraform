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
