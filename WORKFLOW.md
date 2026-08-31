# Workflow

A reproducible loop for building features and fixing bugs with Claude Code, gstack,
and the skills in this repo.

## Invariant

gstack skills read the repository. Any document a skill acts on must be committed
first, and its path passed explicitly:

```
/plan-eng-review docs/specs/icloud-migration.md
```

Do not rely on the skill to locate the file.

## Feature loop

```
1. Write spec        -> docs/specs/<name>.md, commit
2. /plan-eng-review  docs/specs/<name>.md
3. Build             plan mode, one phase at a time
4. /review
5. /qa
6. Commit
```

Step 1 replaces gstack's `/office-hours`. The spec is the artifact that skill would
have produced, so it is skipped.

## Bug loop

```
1. /investigate  <symptom + repro steps>
2. Apply fix
3. /qa           produces the regression test
4. Commit
```

## Supporting steps

| Step | When |
| --- | --- |
| `/prime-codebase` | Once per repo, only when the repo exceeds what fits in context. Re-run after structural change. |
| `/promote-learnings` | End of a project. Moves portable lessons into `~/.claude/CLAUDE.md`. |

Small repos do not need priming. A code graph solves navigation in a codebase too
large to hold in context; below that threshold it adds noise.

## gstack subset in use

Applicable: `/plan-eng-review`, `/review`, `/investigate`, `/qa`, `/qa-only`,
`/cso`, `/retro`, `/document-release`.

Not used: `/office-hours` and `/plan-ceo-review` (product vetting, handled elsewhere).
The `/design-*`, `/devex-review`, `/canary`, `/benchmark`, and `/land-and-deploy`
skills assume a deployed web application and do not apply to infrastructure or
scripting repos.

## Spec format

A spec should contain, at minimum:

- Purpose, and the one requirement that must not be traded away
- Current state as-built
- Target architecture
- Build order in phases, with exit criteria per phase
- Known risks and accepted tradeoffs
- Open questions blocking the first phase

See `docs/specs/` in a consuming repo for examples.
