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
