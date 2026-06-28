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
