# Security Policy

Next Transfer stores government identifiers, uploaded identity documents, résumés, private notes,
Church-related commitments, and location history for individual users. A breach is not an
inconvenience for these users; it is an identity-theft and privacy event. This document states the
rules that apply to everyone working in this repository.

Detailed design lives in [`docs/security/threat-model.md`](docs/security/threat-model.md),
[`docs/security/privacy-classification.md`](docs/security/privacy-classification.md),
[`docs/security/supabase-rls-plan.md`](docs/security/supabase-rls-plan.md), and
[`docs/security/attachment-security.md`](docs/security/attachment-security.md).

---

## Reporting a vulnerability

Report privately to the repository owner. Do not open a public issue, and do not include real user
data, real government numbers, or real document images in a report — describe the class of data
instead.

Include: affected surface (mobile app, Supabase policy, admin portal, CI), reproduction steps, the
data at risk, and the environment (local / development / production). Expect acknowledgement within
72 hours. Do not test against the production project without written authorisation from the owner.

---

## Hard rules

These are not preferences. A change that breaks one of them must be reverted, not debated.

1. **No secrets in this repository.** `.env.example` holds variable names only. No `.env`, key file,
   certificate, keystore, database URL, or service role key is ever committed — see `.gitignore`.
2. **The service role key never reaches a client.** It is not in the Flutter binary, not in a
   `NEXT_PUBLIC_*` variable, not in a client bundle, not in a log line. It exists in the CI secret
   store and in the admin portal's server-side environment only.
3. **Row Level Security is enabled on every user-data table**, with an explicit owner policy. A table
   created without RLS is a defect. No table is exempt "for now".
4. **All storage buckets are private.** Attachments are reached only through short-lived signed URLs.
   No public bucket, no permanent URL, no URL written into an analytics event.
5. **No complete government identifier in a log, an analytics event, or a crash report.** Only masked
   forms leave the local database: `SSS •••• 4821`, `TIN •••• 0197`.
6. **Sensitive fields are excluded from diagnostics.** Crash reports and analytics carry no note body,
   no journal text, no contact note, no document image, no calling or ministering record, no location
   history, no résumé content.
7. **Church-related records are private by default** — temple activity, callings, ministering
   assignments. They are never aggregated into a score, never used to infer worthiness, never shared
   for analytics. See ADR-0012.
8. **No claim of end-to-end encryption.** Next Transfer uses TLS in transit and provider-side
   encryption at rest. Until a designed and implemented E2EE scheme exists, no document, marketing
   copy, or UI string may state or imply end-to-end encryption.
9. **Production data never lands on a developer machine.** Development and testing use synthetic
   fixtures. There is no "copy prod down to debug it".
10. **Least privilege for every credential.** Map API keys are restricted by platform and application
    ID. CI tokens are scoped to the single environment they deploy.

---

## Credential rotation

Rotate immediately, do not wait for a release, when any of the following happens:

- a key or password appears in a chat transcript, a screenshot, an issue, a commit, or a log file;
- a developer with access leaves the project;
- a key is pasted into a third-party tool or a coding agent's context;
- a key's environment scope changes (for example, a development key is used against production).

Rotation procedure: create the replacement in the Supabase or provider dashboard, update the CI
secret store, redeploy consumers, then revoke the old credential and confirm it fails. Record the
rotation date in the owner's private log — not in this repository.

**Known outstanding rotation:** credentials belonging to the deprecated prototype Supabase project
were shared in plaintext during project handover and must be treated as compromised. That project is
not used by this architecture and should be deleted rather than rotated. See
[`docs/legacy-resources.md`](docs/legacy-resources.md).

---

## Data classification summary

Full table in [`docs/security/privacy-classification.md`](docs/security/privacy-classification.md).

| Tier | Examples | Handling |
| --- | --- | --- |
| **P0 Restricted** | Government numbers, ID document images, passport/PSA scans | Masked in UI by default; never in logs, analytics, or crash reports; local storage protected; explicit user action to reveal |
| **P1 Sensitive** | Church commitments, callings, ministering, journal entries, private contact notes, résumés, application files, location history | Private by default; excluded from analytics; manual conflict resolution on sync; never aggregated into a score |
| **P2 Personal** | Name, email, contacts, calendar events, tasks, goals, pathway progress | RLS-owned per user; standard sync; no third-party sharing |
| **P3 Operational** | Sync state, feature flags, device locale, app version | May appear in diagnostics when diagnostics are enabled |
| **P4 Public content** | Country content packs, official links, requirement descriptions | Readable by authenticated users; authored only through the admin portal with audit history |

---

## Reviewer checklist

Before approving any change:

- [ ] No credential, token, or connection string added to a tracked file.
- [ ] Every new table has `ENABLE ROW LEVEL SECURITY` and an owner policy, with a matching RLS test.
- [ ] No new `select *` path that could return another user's row.
- [ ] Any new sensitive field is added to the privacy classification table and to the diagnostics
      strip-list in the same change.
- [ ] No new log statement prints a note body, a document path, a full identifier, or a token.
- [ ] Any new attachment path uses a private bucket and a signed URL with a bounded TTL.
- [ ] No new UI string claims endorsement by an external organisation or claims E2EE.
