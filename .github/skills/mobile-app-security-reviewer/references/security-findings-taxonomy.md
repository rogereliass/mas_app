# Security Findings Taxonomy

Use these categories to keep findings consistent.

## Plain-Language Severity Guide
- Critical: Realistic path to account takeover, privilege escalation to powerful roles, or broad sensitive-data compromise.
- High: Serious exploitable issue with meaningful impact, but narrower scope or stricter preconditions than Critical.
- Medium: Exploitable weakness with constraints, partial mitigations, or lower blast radius.
- Low: Hardening opportunity with limited direct security impact.

## Critical
- Auth bypass leading to account takeover.
- Server-side authorization bypass enabling privilege escalation.
- Sensitive data exfiltration across tenants/users.

## High
- Missing authorization on privileged operations with practical exploit path.
- Token/session handling flaw enabling unauthorized access.
- Secrets exposure that enables backend abuse.

## Medium
- Defense-in-depth gaps with realistic abuse preconditions.
- Overly broad data reads where backend policy partially mitigates.
- Insecure local persistence of moderately sensitive data.

## Low
- Hardening opportunities with low direct impact.
- Information disclosure with limited sensitivity and scope.

## False Positive Criteria
- Server policy/function checks provably block abuse path.
- Code path is unreachable under current architecture constraints.
- Sensitive value is mocked/non-production and non-shipping.

Always include exploitability evidence when assigning Critical or High.

## Release Handling Guidance
- Critical: do not release affected flow without fix or approved exceptional waiver.
- High: fix before release when exploitable; if deferred, document approval, owner, and due date.
- Medium/Low: track in backlog with explicit remediation tasks.
