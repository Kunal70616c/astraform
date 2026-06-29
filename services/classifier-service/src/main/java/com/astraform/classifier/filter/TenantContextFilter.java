package com.astraform.classifier.filter;

import com.astraform.classifier.util.TenantContext;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;

@Component
@Slf4j
public class TenantContextFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        try {
            String tenantId = request.getHeader("X-Tenant-Id");
            String userId   = request.getHeader("X-User-Id");
            TenantContext.setTenantId(tenantId != null ? tenantId : "default");
            TenantContext.setUserId(userId     != null ? userId   : "anonymous");
            chain.doFilter(request, response);
        } finally {
            TenantContext.clear();
        }
    }
}
