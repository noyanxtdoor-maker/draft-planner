# Legacy resources — deprecation inventory

**Status:** Confirmed deprecated. Nothing in this architecture depends on any resource listed here.

The prototype phase produced an experimental repository, a Supabase project, and a Vercel deployment.
They were exploratory. This project does not extend them, does not import their schema or migrations,
does not copy their data, and does not reuse their environment values.

This document exists so the resources can be retired deliberately. **Nothing here is deleted
automatically.** Every deletion is the owner's decision and is performed by the owner.

---

## 1. What was deliberately not carried over

| Not carried over | Reason |
| --- | --- |
| Old repository code | Prototype-quality; new architecture has different module boundaries, a ledger-derived progress model, and a local-first data path |
| Old database schema and data | New schema is built around `activity_ledger`, client-generated UUIDs, tombstones, and sync metadata that the prototype lacks |
| Old migrations | Importing them would encode prototype assumptions into the new baseline; `supabase/migrations/` starts empty |
| Old environment values and API keys | Treated as compromised (see below); new projects get fresh keys |
| Old Vercel deployment and configuration | The Flutter mobile app is never deployed to Vercel; Vercel is reserved for the optional admin portal only (ADR-0010) |
| Old Supabase Storage buckets and objects | Bucket policy differs — all new buckets are private with signed-URL access only |

---

## 2. Retirement checklist

Work top to bottom. Do not begin until the new development-cloud project exists and this repository's
architecture baseline is accepted.

### 2.1 Prototype Supabase project

- Project reference: `facmizjfyvolgwvfgwgo` (region and plan per the owner's Supabase dashboard).
- **Credentials shared in plaintext during handover are compromised.** They include a publishable
  key and a database password. Because the project is being retired, deleting the project is
  preferable to rotating its keys.

Steps:

1. Confirm no application, script, CI job, cron, webhook, or edge function still points at this
   project reference. Search the owner's machine and any deployment for the string
   `facmizjfyvolgwvfgwgo`.
2. If any prototype data has personal value, export it manually to an encrypted local archive. Do
   **not** commit the archive and do **not** import it into the new project — the new schema is
   incompatible by design.
3. Revoke the database password and any access tokens tied to the project.
4. Delete storage buckets and their objects.
5. Pause the project, observe for one week, then delete it.

> Deletion is destructive and irreversible. It requires the owner's explicit action and is listed in
> the approvals section of the handover summary.

### 2.2 Prototype Vercel project

1. Identify the deployment that served the prototype web build.
2. Remove environment variables from the Vercel project **before** deleting it, so values stop
   appearing in build logs.
3. Remove any custom domain or DNS record pointing at it.
4. Delete the project only after confirming no external link depends on it. If a link does, keep a
   static placeholder page instead of deleting.

### 2.3 Prototype GitHub repository

Candidate: `noyanxtdoor-maker/rm-calendar` (public, "A mobile-first field productivity platform").

1. **Do not force-push over it. Do not rewrite its history.** It is not the same project.
2. It is currently **public**. If it ever contained Supabase URLs, keys, or personal data, make it
   private now — before anything else — and treat every credential in its history as compromised.
   Making a repository private does not remove data already cloned or cached, so rotation is still
   required.
3. Archive rather than delete: GitHub's *Archive repository* preserves history read-only and removes
   it from active listings. This retains provenance at no cost.
4. Delete only if the owner is certain no history is worth keeping.

Other repositories in the account (`pick-ur-veggie-farm`, `Calendar`,
`pickurveggieERPfarm-GLM-version`) are **unrelated** to Next Transfer. Do not touch them.

---

## 3. Verification that the new baseline is clean

Run from the repository root. Each command must return nothing.

```bash
grep -ri "facmizjfyvolgwvfgwgo" . --exclude-dir=.git --exclude=legacy-resources.md
```

```bash
grep -rEi "sb_(publishable|secret)_|service_role|eyJhbGciOi" . --exclude-dir=.git
```

```bash
git log --all -p | grep -ciE "sb_(publishable|secret)_|SUPABASE_SERVICE_ROLE_KEY=[^[:space:]]"
```

The repository-hygiene workflow in `.github/workflows/` runs equivalent checks on every push, so a
regression fails CI rather than sitting undetected. See
[`docs/implementation/ci-cd-plan.md`](docs/implementation/ci-cd-plan.md).

---

## 4. Guard rails

- No force-push to any repository other than a branch of this one.
- No deletion of any GitHub, Supabase, or Vercel project by an automated process or a coding agent.
- No import of prototype data into `development` or `production`.
- The new development-cloud project is created fresh, with fresh keys, per
  [`docs/architecture/environment-strategy.md`](docs/architecture/environment-strategy.md).
