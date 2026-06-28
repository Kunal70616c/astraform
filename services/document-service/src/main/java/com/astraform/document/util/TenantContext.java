package com.astraform.document.util;

/**
 * Per-request tenant + user context stored in ThreadLocal.
 *
 * MVP  : set headers manually in Postman (X-Tenant-Id, X-User-Id).
 * Later: API Gateway extracts these from JWT and injects them — zero code change here.
 */
public class TenantContext {

    private static final ThreadLocal<String> TENANT_ID = new ThreadLocal<>();
    private static final ThreadLocal<String> USER_ID   = new ThreadLocal<>();

    public static void setTenantId(String v) { TENANT_ID.set(v); }
    public static String getTenantId()        { return TENANT_ID.get(); }

    public static void setUserId(String v)    { USER_ID.set(v); }
    public static String getUserId()          { return USER_ID.get(); }

    public static void clear() { TENANT_ID.remove(); USER_ID.remove(); }
}
