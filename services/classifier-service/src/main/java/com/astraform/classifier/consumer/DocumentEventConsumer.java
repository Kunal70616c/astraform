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
