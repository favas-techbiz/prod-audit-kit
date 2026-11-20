---
category: multi-tenant
prefix: MT
title: Multi-tenant checks
applies_when: the codebase has a tenant concept (tenant, organization, company, account, workspace, client ID scoping data). If none is found, mark the whole category NOT_APPLICABLE.
---
Format: `ID | default severity | kind`. kind = code or process (process → report as MANUAL).

## Data isolation

### ISO-01 | critical | code — Every query filtered by tenant
Look for: queries/repositories on tenant-owned tables without tenant filter. Check whether filtering is centralized (ORM global filter, row-level security, base repository). If centralized, look for bypasses (raw SQL, IgnoreQueryFilters, unscoped queries).

### ISO-02 | critical | code — Tenant derived from authenticated identity
Look for: tenantId read from request body, query string, header, or route and trusted without matching the token/session.

### ISO-03 | critical | code — Background jobs carry tenant context
Look for: jobs, cron tasks, queue consumers that query tenant data with no tenant parameter or that loop over all data.

### ISO-04 | critical | code — Tenant-aware cache keys
Look for: cache keys that omit tenant ID for tenant-owned data.

### ISO-05 | high | code — File storage isolation
Look for: upload paths/buckets without tenant prefix; download endpoints that do not verify tenant.

### ISO-06 | high | code — Reports, search, and exports filtered
Look for: report/export/search endpoints or index queries without tenant filter.

### ISO-07 | high | code — Unique constraints per tenant
Look for: UNIQUE on business keys (email, code, name) without tenant_id, or tenant-scoped keys made globally unique by mistake.

### ISO-08 | medium | code — Cross-tenant information leaks via uniqueness checks
Look for: "already exists" errors that reveal records in other tenants.

## Isolation model

### MODEL-01 | low | process — Isolation model documented
Identify the model in use (shared DB + tenant_id, schema per tenant, DB per tenant) and report it in the summary. Flag if a tenant cannot be moved to dedicated storage later without code changes (suggestion only).

## Configuration

### CONF-01 | medium | code — Tenant-specific settings
Check: time zone, working hours, branding, auth mode, features come from tenant config, not hardcoded globals.

### CONF-02 | medium | code — Per-tenant feature flags and plan limits
Look for: limits (users, trainers, storage) not enforced server-side.

## Performance and fairness

### PERF-01 | medium | code — Noisy neighbor protection
Look for: rate limits/quotas that are global only, not per tenant.

### PERF-02 | medium | code — Tenant-first indexes
Look for: tenant-scoped query patterns without an index starting with tenant_id.

## Lifecycle

### LIFE-01 | medium | code — Tenant onboarding
Check: a defined path creates tenant, default roles, default data, first admin.

### LIFE-02 | medium | code — Suspension handling
Check: suspended/expired tenants are blocked consistently (API, jobs, sub-apps).

### LIFE-03 | high | code — Tenant deletion and export
Check: a way to export and delete all tenant data, including files.

### LIFE-04 | medium | code — Migrations across tenants
Applies to schema/DB-per-tenant. Check migrations run for every tenant.

## Cross-tenant cases

### CROSS-01 | high | code — Users in multiple tenants
Check: token/session scoped to the active tenant; switching tenant re-issues context.

### CROSS-02 | high | code — Super-admin access
Look for: platform-admin paths that bypass tenant filters without audit logging.

### CROSS-03 | high | code — Shared resources across tenants
Check: if a resource (e.g., trainer) can serve multiple tenants, conflict/availability checks span tenants.

## Testing

### TEST-01 | high | code — Cross-tenant access tests
Look for: automated tests that attempt tenant B access as tenant A. Report missing if none exist.
