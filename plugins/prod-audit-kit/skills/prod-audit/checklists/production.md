---
category: production
prefix: PROD
title: Production readiness
applies_when: always
---
Format of each check: `ID | default severity | kind`, then what to check, where to look, and when it passes.
kind = code (verify in source) or process (cannot be proven from code; report as MANUAL).

## Concurrency and data consistency

### CONC-01 | critical | code — Double booking / overselling
Check: resources with limited capacity (slots, seats, stock, coupons, trainer time) are reserved atomically.
Look for: "check availability, then insert/update" in two separate steps without a lock, transaction or DB constraint. Availability endpoints whose result is trusted at write time.
Pass: DB unique/exclusion constraint, SELECT ... FOR UPDATE inside a transaction, or atomic conditional update (UPDATE ... WHERE remaining > 0).

### CONC-02 | high | code — Lost updates
Check: concurrent edits of the same record are detected.
Look for: update endpoints that overwrite full records with no version/updated_at comparison.
Pass: optimistic locking (version column / ETag / If-Match) or explicit locking.

### CONC-03 | high | code — Double submission
Check: create/payment/booking endpoints tolerate retries and double clicks.
Look for: POST handlers with side effects and no idempotency key or natural unique key; submit buttons not disabled while pending.
Pass: idempotency key stored with a unique constraint, or a natural unique constraint, plus a UI pending state.

### CONC-04 | medium | code — Stale UI data
Check: server re-validates at submit time; UI handles conflict responses and refreshes.
Look for: frontend sends a pre-computed "available" flag or price that the server trusts.

### CONC-05 | high | code — Partial failures across services
Check: a DB write plus an external side effect (email, calendar, another service) cannot leave inconsistent state silently.
Look for: external calls inside DB transactions, or after commit with no retry/outbox.
Pass: outbox pattern, retry queue, or compensating action.

### CONC-06 | medium | code — Duplicate event processing
Look for: queue/webhook consumers that insert or charge without checking a processed-message ID.
Pass: dedupe table / unique key on message ID, or idempotent upserts.

### CONC-07 | high | code — Non-atomic counters and balances
Look for: read value → modify in code → save (x = x + 1, balance -= amount).
Pass: atomic DB increment, conditional update, or locked row.

## Time and dates

### TIME-01 | high | code — Time zones
Look for: local DateTime/new Date() stored without zone, date strings parsed without offset, server-local time in business logic.
Pass: UTC storage (timestamptz or equivalent), conversion only at display.

### TIME-02 | high | code — Overlap boundary rules
Look for: overlap checks using <= / >= inconsistently across the codebase.
Pass: one consistent half-open rule: existing.start < new.end AND new.start < existing.end.

### TIME-03 | medium | code — Rescheduling and cancellation
Look for: availability queries that ignore status or count CANCELLED rows; no late-cancellation rule if the domain needs one.

### TIME-04 | medium | code — Past dates
Check: the server rejects bookings/schedules in the past, not only the date picker.

## Reliability

### REL-01 | high | code — Timeouts, retries, circuit breakers
Look for: HTTP clients with no timeout; retries without backoff; no handling for dependency failure.

### REL-02 | medium | code — Graceful degradation
Check: failure of non-critical dependencies (email, analytics) does not fail the main request.

### REL-03 | medium | code — Health checks and safe restarts
Look for: no /health or readiness endpoint; no graceful shutdown handling (SIGTERM).

### REL-04 | high | code — Safe migrations
Look for: migrations that drop/rename columns still used by running code, add NOT NULL without default on large tables, or lock large tables.

### REL-05 | high | process — Tested backups
Report as MANUAL: confirm backups exist and a restore has been tested.

## Performance

### PERF-01 | high | code — N+1 queries, missing indexes, unbounded queries
Look for: queries inside loops; list endpoints without pagination/limit; filters/joins on columns with no index in migrations.

### PERF-02 | high | code — Cache correctness
Look for: caches with no invalidation on write; availability or permissions read from cache when making a write decision.

### PERF-03 | medium | code — Rate limiting
Look for: public or expensive endpoints without rate-limiting middleware.

### PERF-04 | medium | code — Long-running work in requests
Look for: report generation, bulk imports, email batches, file processing run synchronously in HTTP handlers.

## Observability

### OBS-01 | medium | code — Structured logs with correlation ID
Look for: console.log/print-style logging; no request ID propagated to downstream calls.

### OBS-02 | medium | process — Metrics and alerts
Report as MANUAL unless metrics instrumentation is visible in code.

### OBS-03 | high | code — Business audit log
Check: create/update/cancel/approve actions record who, what, and when.

## Data integrity and validation

### DATA-01 | high | code — Server-side validation
Look for: request DTOs/models without validation; reliance on frontend validation only.

### DATA-02 | high | code — Database constraints
Look for: missing foreign keys, NOT NULL, UNIQUE, CHECK constraints for business rules enforced only in code.

### DATA-03 | medium | code — Soft vs hard delete consistency
Check: deleting/deactivating an entity handles dependents (e.g., future bookings of a deactivated trainer); soft-deleted rows are excluded from queries.

### DATA-04 | high | code — Status state machine
Look for: status fields set freely from request input; no guard against invalid transitions (e.g., CANCELLED → CONFIRMED).
Pass: central transition guard; conditional update WHERE status = expected.

## Configuration and operations

### CONF-01 | critical | code — Secrets in code
Look for: API keys, passwords, connection strings, private keys committed in source or config files.

### CONF-02 | low | code — Feature flags for risky features
Suggestion only, where large risky features have no toggle.

### CONF-03 | medium | code — User-facing errors leak internals
Look for: stack traces, SQL errors, or exception messages returned in API responses or shown in the UI.
