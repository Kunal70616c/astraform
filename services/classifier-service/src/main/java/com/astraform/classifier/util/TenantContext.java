package com.astraform.classifier.util;

public class TenantContext {
    private static final ThreadLocal<String> TENANT_ID = new ThreadLocal<>();
    private static final ThreadLocal<String> USER_ID   = new ThreadLocal<>();

    public static void setTenantId(String v) { TENANT_ID.set(v); }
    public static String getTenantId()        { return TENANT_ID.get(); }
    public static void setUserId(String v)    { USER_ID.set(v); }
    public static String getUserId()          { return USER_ID.get(); }
    public static void clear()                { TENANT_ID.remove(); USER_ID.remove(); }
}
