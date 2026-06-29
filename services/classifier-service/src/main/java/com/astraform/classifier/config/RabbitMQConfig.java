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
