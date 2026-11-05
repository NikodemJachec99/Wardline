# Security Policy

Wardline is a university project. **The repository contains only fictional patient data.** No real people, no real medical records.

## Reporting a vulnerability

Report privately through GitHub **private vulnerability reporting**:
[Security → Report a vulnerability](https://github.com/NikodemJachec99/Wardline/security/advisories/new).

Please do not open a public issue for security problems. Include the affected component (app, RLS policy, RPC, workflow), steps to reproduce and impact. We aim to respond within 7 days during the semester.

## Scope

In scope: authorization bypass (e.g. writing to `patients` without the RPC, a nurse changing status), leaking keys, history mutation, CI workflow injection.

Out of scope: the fictional dataset itself, denial of service against the free Supabase tier.

## Secrets

- Only the public Supabase anon key is used by the app, passed at build time from a git-ignored `.env.json`.
- The `service_role` key is never committed and never shipped in the app.
- Secret scanning with push protection is enabled on this repository.
