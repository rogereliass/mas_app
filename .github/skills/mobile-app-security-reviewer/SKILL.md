---
name: mobile-app-security-reviewer
description: 'Expert mobile app security review for Flutter + Supabase apps. Use for threat modeling, code security audits, finding auth/RBAC/data-exposure flaws, validating exploitability, and implementing safe code fixes with verification.'
argument-hint: 'Target area (optional): auth, API/data, storage, networking, secrets, notifications, or full app pass'
user-invocable: true
---

# Mobile App Security Reviewer

Run a security-focused review that does more than report issues: identify exploitable risks, implement minimal safe code fixes, and verify regressions are not introduced.

## When to Use
- You need a full security review of a mobile feature before release.
- You suspect auth, authorization, or data exposure vulnerabilities.
- You need concrete code-level remediation, not only findings.
- You want a repeatable security sign-off workflow.

## Inputs To Confirm
1. Target scope: full app, module, or specific files/endpoints.
2. Risk tolerance: strict production hardening vs pragmatic quick pass.
3. Constraints: release deadline, backward compatibility, migration limits.
4. Allowed changes: code only, config only, or both.

Scope behavior:
- If the user prompt says full app or equivalent, run a full-app review.
- If the user prompt names a feature/module/files, run a feature-based review on that scope.
- If scope is not specified, ask one concise clarification before proceeding.

Remediation behavior:
- Always report findings first.
- Do not edit code until explicit user approval is given.

## Security Review Workflow
1. Map attack surface.
2. Build threat model.
3. Audit code paths by risk category.
4. Validate exploitability and impact.
5. Prioritize by severity and blast radius.
6. Implement code fixes.
7. Verify with analysis/tests.
8. Produce remediation report.

## Step-by-Step Procedure

### 1) Map Attack Surface
Inspect and inventory:
- Auth flows: signup, login, OTP, reset, session refresh, logout.
- Authorization boundaries: role/rank checks, feature gating, server-side enforcement.
- Data flows: client -> API/Supabase -> storage -> UI.
- Trust boundaries: device storage, network, backend RPC/functions.
- Sensitive operations: profile updates, role changes, bulk actions, admin tools.

Output:
- Explicit list of entry points, privileged operations, and high-value data.

### 2) Build Threat Model
For each sensitive flow, document:
- Asset: what needs protection (PII, role claims, tokens, troop data).
- Actor: anonymous user, authenticated low-rank user, malicious insider.
- Abuse case: how the actor could bypass checks or exfiltrate data.
- Control(s): existing mitigation(s) and potential gaps.

Use [Threat Model Matrix](./references/threat-model-matrix.md).

### 3) Audit By Risk Category
Review source with focused checks:
- Auth/session issues: token misuse, weak reset/OTP handling, session fixation.
- Authorization/RBAC flaws: client-only enforcement, rank bypass, missing server checks.
- Data exposure: over-broad selects, logs leaking PII, insecure local caching.
- Injection/query safety: unsafe string interpolation in filters/queries.
- Secrets/config: keys/tokens in code, insecure env handling.
- Transport/storage: missing TLS assumptions, insecure on-device persistence.
- Abuse controls: brute-force/rate-limit gaps on sensitive endpoints.

Use [Security Findings Taxonomy](./references/security-findings-taxonomy.md).

### 4) Validate Exploitability
For each suspected issue:
- Attempt a realistic abuse path using current code assumptions.
- Confirm whether server-side controls (RLS, function auth checks) block it.
- Mark as:
  - Confirmed exploitable
  - Defense-in-depth weakness
  - False positive (document why)

Do not claim critical issues without a concrete exploit path or strong evidence.

### 5) Prioritize
Rank by:
- Severity: Critical/High/Medium/Low
- Likelihood: easy vs difficult to exploit
- Blast radius: single user vs tenant/system-wide
- Fix effort: quick win vs deep refactor

Fix order:
1. Critical/High exploitable issues
2. Medium exploitable issues
3. Defense-in-depth hardening

### Severity Policy (Plain Language)
- Critical: attacker can take over accounts, escalate to admin, or read/modify sensitive cross-user data with realistic effort.
- High: serious security break with practical exploit path but narrower impact or stronger preconditions than Critical.
- Medium: meaningful weakness that is exploitable only with notable constraints or is partially mitigated.
- Low: hardening issue with limited direct security impact.

Release guidance:
- Critical: block release until fixed or formally waived with documented mitigation and deadline.
- High: fix before release when exploitable; if deferred, require explicit approval, owner, and near-term due date.
- Medium/Low: can be scheduled, but must be tracked with clear follow-up tasks.

### 6) Implement Fixes
Rules for remediation:
- Prefer server-side enforcement over client-only checks.
- Keep fixes minimal and scoped; avoid unrelated refactors.
- Preserve existing app architecture patterns.
- Add defensive validation at trust boundaries.
- Remove sensitive logs and reduce returned data shape to minimum needed.

Approval gate:
- Start this step only after user approves remediation based on the report.

For each fix:
1. Patch vulnerable path.
2. Add/adjust tests where practical.
3. Re-check adjacent flows for regressions.

### 7) Verify
Run applicable checks after edits:
- Static analysis/lint (for Flutter: `flutter analyze`).
- Relevant unit/widget/integration tests.
- Manual sanity checks for changed auth/role/data flows.

A fix is incomplete if it is unverified.

### 8) Report
Produce findings in this format:
1. Severity + title
2. Location (file/symbol)
3. Exploit scenario
4. Root cause
5. Exact fix applied
6. Verification evidence
7. Residual risk / follow-up

## Decision Logic
- If server-side authorization is absent or weak: block release for affected flows.
- If issue is client-side only but server is safe: treat as defense-in-depth unless it leaks sensitive data.
- If fix would be high-risk near release: implement containment + create follow-up hardening task.
- If evidence is inconclusive: mark as needs-validation, not confirmed vulnerability.

## Quality Gates (Definition of Done)
- Every high/critical finding has either:
  - a merged fix, or
  - documented, approved mitigation with deadline.
- No secrets/tokens hardcoded in committed code.
- No sensitive data exposed in logs for changed paths.
- Authorization is enforced server-side for changed privileged operations.
- Static analysis passes for touched areas.
- Security report includes exploitability and verification evidence.

## Output Contract
Return:
1. Prioritized findings list (highest risk first).
2. Recommended remediation plan per finding (before code edits).
3. After user approval: code changes applied to fix confirmed issues.
4. Verification results and any remaining risks.
5. Recommended next hardening tasks.

## Notes For This Codebase
- Follow existing architecture/layering patterns; place backend calls in data layer.
- Preserve existing route/state-management patterns unless security fix requires minimal deviation.
- Prefer explicit allowlist-style role checks for privileged actions.
