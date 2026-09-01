# AI Agent Workflow Rules — ЧтоХочу

> **Status:** Authoritative. These rules govern how AI agents (and developers using
> them) work on the ЧтоХочу codebase. They operationalize AGENTS.md §18.

## 1. Read AGENTS.md First

Before making any change, an agent MUST read `AGENTS.md` in full. It is the
engineering and architecture contract and the authority above implementation but below
the architecture documentation.

The source-of-truth hierarchy (AGENTS.md §2) is:

```text
Product requirements
        ↓
Architecture documentation (docs/)
        ↓
AGENTS.md
        ↓
ADRs (docs/adr/)
        ↓
Implementation
        ↓
Existing prototype
```

The existing prototype is the **lowest** authority. Prototype patterns (e.g. BLoC /
GetIt in Flutter) are disposable and must not be treated as architecture to preserve.

## 2. Read the Relevant Docs Before Implementing

Before implementing a feature, an agent MUST read the documentation relevant to the
area of change:

| Area | Read first |
|------|-----------|
| Backend | `docs/20-backend/architecture.md`, `docs/01-architecture/backend.md` |
| API | `docs/20-backend/api.md`, `docs/20-backend/api-versioning.md`, `docs/20-backend/api-errors.md` |
| Realtime | `docs/20-backend/realtime.md`, `docs/20-backend/realtime-events.md` |
| Flutter | `docs/30-client/flutter-architecture.md`, `docs/30-client/state-management.md` |
| Web | `docs/40-web/web-architecture.md`, the relevant app doc |
| Infrastructure | `docs/50-infrastructure/local-development.md`, `docs/10-development/docker.md` |
| Security | `docs/01-architecture/security.md` |
| Boundaries | `docs/01-architecture/application-boundaries.md`, `docs/01-architecture/api-boundary.md` |

If a task spans areas, read all the relevant docs before starting.

## 3. Inspect Existing Code

Before writing new code, an agent MUST inspect the existing code in the target area:

- How are similar features structured?
- What patterns are already in use?
- Where do controllers, actions, domain models, and resources live?
- What tests exist for neighbouring features?

The goal is the **smallest correct change** that fits the existing architecture, not a
new pattern invented for the task.

## 4. Never Silently Change Architecture

An agent MUST NOT change the architecture without following the process in AGENTS.md
§2:

1. **Stop.** Do not proceed with the architectural change.
2. **Explain the conflict.** Describe why the task requires a change that diverges
   from the documented architecture.
3. **Propose a solution.** Offer options and a recommendation.
4. **Request approval.** Wait for explicit approval before proceeding.
5. **Document the decision.** Record the outcome in an ADR
   (`docs/adr/ADR-NNN-<topic>.md`).

Architectural changes include: introducing a new dependency, a new pattern, a new
service, a new layer, a new transport, or diverging from the documented boundaries.

## 5. Never Overwrite User Changes

An agent MUST NOT overwrite changes made by the user (or another agent) without
explicit instruction. Concretely:

- Do not revert edits the user made to files you are also editing.
- Do not regenerate files the user has hand-edited (generated files must not be
  hand-edited, but if they appear to be, stop and ask).
- Do not reformat code the user has intentionally formatted.
- Do not delete files or directories unless the task explicitly requires it.
- When in doubt, stop and ask.

## 6. Report Modified Files

At the end of a task, an agent MUST report:

- Every file created, modified, or deleted, with the absolute path.
- A one-line summary of what changed in each file.
- Whether documentation was updated (and which files).
- Whether an ADR was created or updated.

This report is the agent's final deliverable and is how the user verifies the work.

## 7. Report Validation Results

An agent MUST run the relevant validation commands and report the results:

| Area | Validation |
|------|-----------|
| Backend | `php artisan test`, Laravel Pint |
| Flutter | `flutter analyze`, `dart format --set-exit-if-changed`, `flutter test` |
| Web | `nuxt typecheck`, ESLint, unit tests |

The report must include:

- The exact commands run.
- Pass/fail status.
- Any failures with the relevant output.
- Fixes applied and re-run results.

If validation cannot be run (e.g. missing tooling), say so explicitly rather than
omitting it.

## 8. Stop and Document When Uncertain

When an agent is uncertain about an architectural boundary, a requirement, or the
correct approach, it MUST stop and follow the uncertainty flow (AGENTS.md §18):

```text
inspect documentation
        ↓
inspect existing architecture
        ↓
identify boundary
        ↓
make smallest correct change
        ↓
document architectural decision if necessary
```

If the documentation does not resolve the uncertainty, the agent MUST:

1. State what is uncertain.
2. State what the documentation says (or that it is silent).
3. Propose the smallest change that does not commit to an undocumented architectural
   decision.
4. Ask for direction rather than guessing.

Do not invent a new pattern to resolve uncertainty. Do not copy prototype patterns
into the production codebase. Do not introduce a dependency to avoid a small amount of
boilerplate.

## 9. Checklist Before Finishing

- [ ] Read `AGENTS.md` and relevant `docs/`.
- [ ] Inspected existing code in the target area.
- [ ] No architectural change made silently.
- [ ] No user changes overwritten.
- [ ] Validation commands run and results reported.
- [ ] Modified files listed with summaries.
- [ ] Documentation updated if behaviour changed.
- [ ] ADR created if an architectural decision was made.
- [ ] No forbidden practices introduced (AGENTS.md §16).
