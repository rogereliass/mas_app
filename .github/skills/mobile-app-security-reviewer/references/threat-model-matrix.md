# Threat Model Matrix

Use this table during review for each sensitive feature/flow.

| Flow | Asset | Actor | Abuse Case | Existing Control | Gap | Severity | Fix |
|---|---|---|---|---|---|---|---|
| Example: role update endpoint | Role assignments | Authenticated low-rank user | Escalate own role via crafted request | Client hides admin button | No server-side role check | Critical | Enforce role/rank check in backend function + test |

Guidance:
- Keep entries concrete and testable.
- Phrase abuse case as a real attacker action.
- Add direct file/function references in Fix column when available.
