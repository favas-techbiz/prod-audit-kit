---
category: security
prefix: SEC
title: Security measures
applies_when: always
---
Format: `ID | default severity | kind`. kind = code or process (process → report as MANUAL).

## Authentication

### AUTHN-01 | critical | code — Password storage and MFA
Look for: plain/MD5/SHA1 password hashing; custom crypto. Pass: bcrypt/argon2/scrypt/PBKDF2 with proper cost. Note MFA availability for admins.

### AUTHN-02 | high | code — Brute-force protection
Look for: login, OTP, password reset endpoints without rate limit or lockout.

### AUTHN-03 | high | code — Token lifetime and revocation
Look for: very long-lived access tokens; logout that only clears client storage; no refresh-token rotation or revocation list.

### AUTHN-04 | critical | code — SSO / token validation in every app
Look for: tokens decoded without signature verification (e.g., jwt.decode without verify); missing issuer/audience/expiry checks; tokens accepted from URL query and trusted; missing state/nonce in OIDC flows.

### AUTHN-05 | medium | code — Session fixation
Check: session ID regenerated after login.

## Authorization

### AUTHZ-01 | critical | code — Server-side permission checks
Look for: controllers/routes with no auth or permission middleware/attribute; permission checks only in frontend.

### AUTHZ-02 | critical | code — IDOR
Look for: handlers that load a record by ID from the URL/body and return or modify it without checking owner, tenant, or scope.

### AUTHZ-03 | high | code — Mass assignment
Look for: request bodies bound directly to ORM entities (Object.assign(entity, req.body), model.update(req.body), [Bind] all) allowing role, tenantId, status, price changes.

## Input and output handling

### INPUT-01 | critical | code — SQL / NoSQL injection
Look for: string concatenation or interpolation in queries, raw query APIs with user input.

### INPUT-02 | high | code — XSS
Look for: innerHTML, dangerouslySetInnerHTML, [innerHTML], v-html, bypassSecurityTrust*, unescaped template output; missing CSP.

### INPUT-03 | high | code — CSRF
Applies when cookie-based auth is used. Look for: state-changing endpoints without CSRF token and cookies without SameSite.

### INPUT-04 | high | code — File uploads
Look for: no type/size checks, original filenames used on disk, uploads stored under web root, no content-type validation.

### INPUT-05 | high | code — SSRF
Look for: server fetching user-supplied URLs (webhooks, image import, link preview) with no allowlist or internal-IP blocking.

### INPUT-06 | critical | code — Path traversal and command injection
Look for: file paths built from user input; exec/spawn/system/Process.Start with user input.

## Data protection

### PRIV-01 | high | code — HTTPS and HSTS
Look for: http:// URLs for APIs in production config; no HSTS header or HTTPS redirect.

### PRIV-02 | high | code — Sensitive data in logs and at rest
Look for: logging of passwords, tokens, full request bodies, personal data; sensitive columns stored unencrypted where encryption is expected.

### PRIV-03 | medium | code — Over-exposed responses
Look for: returning full entities (password hash, internal flags, other users' data) instead of DTOs.

### PRIV-04 | medium | code — Detailed errors to clients
Look for: exception details returned to the client in production mode.

## Secrets and dependencies

### SECRET-01 | critical | code — Secrets in repository
Look for: keys/passwords/tokens in source, .env files committed, appsettings/config with real credentials. Check .gitignore covers env files.

### SECRET-02 | medium | process — Dependency vulnerabilities
If lockfiles exist, suggest running the ecosystem audit command (npm audit, pip-audit, dotnet list package --vulnerable). Report notably outdated major versions found in manifests.

### SECRET-03 | medium | code — Least privilege
Look for: DB connection as root/sa/postgres superuser; cloud credentials with wildcard permissions in IaC.

## API and infrastructure

### INFRA-01 | high | code — Rate limiting per user/IP
Look for: absence of rate-limit middleware on API.

### INFRA-02 | high | code — CORS
Look for: origin "*" or reflected origin together with credentials; overly broad allowlists.

### INFRA-03 | medium | code — Security headers
Look for: missing helmet/equivalent; no CSP, frame-ancestors/X-Frame-Options, X-Content-Type-Options.

### INFRA-04 | high | code — Security audit events
Check: logins, failed logins, permission changes, and data exports are logged.

### INFRA-05 | medium | process — Penetration testing / OWASP review
Report as MANUAL.
