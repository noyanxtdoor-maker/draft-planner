# Contributing to Next Transfer

This repository is architecture-first. Documentation is a deliverable, not a byproduct. A change that
alters behaviour without updating the document that describes that behaviour is incomplete.

Human and agent contributors follow the same rules. Coding agents must additionally read
[`docs/implementation/codex-handoff.md`](docs/implementation/codex-handoff.md) before their first edit.

---

## Invariants

Do not break these. If a task appears to require breaking one, stop and ask the repository owner.

1. **Actual progress is derived, never typed.** No code path lets a user set an "actual" value. Actuals
   come from `activity_ledger` rows written by confirmed source records. Goals are editable; actuals
   are not. See [`docs/product/progress-rules.md`](docs/product/progress-rules.md).
2. **A scheduled event that passes is not a completed event.** Time passing produces no ledger row.
3. **Every ledger write is idempotent.** A write carries an `idempotency_key`; a repeat is a no-op.
   Corrections are reversals, never edits or deletes of history.
4. **The five-item bottom navigation is fixed**: Home, Planner, Pathways, Contacts, More. Maps and
   Progress are secondary modules, never tabs. See
   [`docs/product/navigation-contract.md`](docs/product/navigation-contract.md).
5. **Local-first.** A user action writes locally and the UI updates from the local database. No user
   action blocks on the network.
6. **RLS on every user-data table**, with a test proving another user cannot read the row.
7. **No spiritual scoring.** No righteousness, worthiness, or faithfulness metric; no aggregate
   spiritual percentage. Factual statuses only. See ADR-0012.
8. **Next Transfer never submits an external application.** State moves to `submitted_by_user` only
   after explicit user confirmation. See ADR-0011.
9. **No secrets in the repository.** See [`SECURITY.md`](SECURITY.md).
10. **Government and program facts live in content packs**, not in Dart or SQL logic, and every record
    carries its source URL and verification dates.

---

## Branching and commits

- `main` is protected and always reflects a coherent architecture baseline.
- Work on `feat/<short-slug>`, `fix/<short-slug>`, `docs/<short-slug>`, or `chore/<short-slug>`.
- Conventional Commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`, `adr:`.
  Scope where useful — `feat(planner): add outcome report sheet`.
- One logical change per commit. A schema change and its RLS policy and its test belong together.

## Pull requests

A pull request must state:

1. what changed and why;
2. which invariant it touches, if any, and how it stays intact;
3. which documents were updated;
4. how it was verified — tests run, scenarios exercised;
5. anything deliberately left out.

Required before merge: CI green, no secrets added, docs updated, tests added for new domain rules,
and for any schema change an accompanying migration plus RLS test.

## Architecture Decision Records

Any decision that constrains future work gets an ADR. Copy
[`docs/adr/0000-template.md`](docs/adr/0000-template.md), take the next number, and link it from
[`docs/adr/README.md`](docs/adr/README.md). Never edit an accepted ADR's decision — supersede it with a
new ADR and mark the old one `Superseded by ADR-NNNN`.

## Documentation conventions

- Mermaid for diagrams. No binary diagram formats.
- Explicit tags for decision status: **Confirmed**, **Recommended**, **Assumption**, **Risk**,
  **Deferred**. The register is [`docs/decision-status.md`](docs/decision-status.md).
- Concrete over generic. Name the table, the field, the formula, the acceptance criterion. Statements
  like "follow best practices" or "make it scalable" are rejected in review.

## Design references

`design/stitch_exports/` holds raw exports and screenshots. They are **visual reference only**.
Do not lift their HTML, sample data, or Tailwind classes into the product. Extract tokens, hierarchy,
and density; then implement in Flutter against
[`docs/design/design-system.md`](docs/design/design-system.md) and
[`packages/design_tokens/tokens.json`](packages/design_tokens/tokens.json), which is the single source
of truth for colour, spacing, radius, and type.

## Content changes

Country and program information is edited as content, with `source_url`, `authority`,
`effective_date`, `last_verified_date`, `next_review_date`, and a verification status. A content change
never ships as a hardcoded string. `Verified` means the source was checked on that date — it never
means Next Transfer endorses the organisation.

## Language

Neutral, factual, non-judgemental. Never imply endorsement by the Church, BYU–Pathway, a government
agency, a school, or an employer. Never imply a spiritual verdict. Do not claim a document is legally
required for every user; use the requirement levels defined in
[`docs/data/content-pack-model.md`](docs/data/content-pack-model.md).
