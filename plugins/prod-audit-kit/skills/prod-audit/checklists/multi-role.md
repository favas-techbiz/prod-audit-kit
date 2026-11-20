---
category: multi-role
prefix: RBAC
title: Multi-role (RBAC) checks
applies_when: the codebase has more than one role or permission level. If only a single user type exists, mark NOT_APPLICABLE.
---
Format: `ID | default severity | kind`. kind = code or process (process → report as MANUAL).

## Permission design

### PERM-01 | medium | code — Permissions, not role names
Look for: hardcoded role-name checks (role == "admin", IsInRole("Admin"), *ngIf role === ...) scattered across code.
Pass: central role → permission mapping and checks by permission.

### PERM-02 | medium | code — Multiple roles per user
Check: rule for combining permissions of multiple roles is defined in one place.

### PERM-03 | high | code — Scope, not only action
Look for: permission checks that verify the action but not the scope (own, department, tenant, all).

## Enforcement

### ENF-01 | critical | code — Server-side enforcement on every endpoint
Look for: endpoints missing authorization; frontend route guards with no matching backend check.

### ENF-02 | critical | code — Vertical and horizontal escalation
Look for: admin-only endpoints reachable by lower roles; handlers not checking department/owner scope.

### ENF-03 | high | code — Field-level access
Look for: same response DTO for all roles exposing cost, salary, or personal data to roles that should not see it; update endpoints letting lower roles change restricted fields.

### ENF-04 | high | code — Role changes take effect immediately
Look for: roles/permissions embedded in long-lived tokens with no refresh or server-side check.

## Role management

### MGMT-01 | critical | code — Role assignment limits
Look for: users able to assign themselves roles, or assign roles higher than their own.

### MGMT-02 | medium | code — Last admin protection
Check: removing/demoting the last admin is blocked.

### MGMT-03 | high | code — Audit of role changes
Check: role and permission changes are logged with actor and time.

## Workflows with multiple admins

### FLOW-01 | high | code — Concurrent approvals
Look for: approve/reject handlers that read status then update without a conditional update or lock.

### FLOW-02 | high | code — Self-approval
Look for: approval endpoints that do not block the creator approving their own request.

### FLOW-03 | low | code — Delegation
Suggestion only: no delegation path for absent approvers.

### FLOW-04 | low | code — Ownership visibility
Check: records expose last modified by/at for multi-admin editing.

## User experience

### UX-01 | low | code — UI adapts to permissions
Look for: buttons/menus shown that lead to 403.

### UX-02 | medium | code — Forbidden route handling
Check: direct navigation to forbidden pages shows a proper 403 page.

### UX-03 | high | code — Notification audience
Look for: notifications/emails sent to recipients without checking their permission to see the content.

## Testing

### TEST-01 | high | code — Permission matrix tests
Look for: tests covering role × action × scope, including negative cases. Report missing if none.
