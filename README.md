# claude-context-kit

Two Claude Code skills for working in codebases you didn't write, and for keeping
what you learn.

They're independent of each other and independent of any particular workflow, but
they were built to sit either side of [gstack](https://github.com/garrytan/gstack):
one feeds context *into* planning, the other collects lessons *out of* shipping.

| Skill | What it does |
|---|---|
| `prime-codebase` | Builds a local code graph and a written map of an unfamiliar repo, then wires them into `~/.claude/CLAUDE.md` so every later session starts oriented. |
| `promote-learnings` | Reviews what gstack recorded on a project and helps you promote the genuinely portable lessons into your personal `CLAUDE.md`, where they apply everywhere. |

## The idea

Claude Code reads two memory files at the start of every session: your personal
`~/.claude/CLAUDE.md` (loads in every repo) and the project's `./CLAUDE.md` (loads
in that repo). Anything you want a skill to know has to end up in one of them.

That's all these skills do. No integration, no daemon, no database.

```
prime-codebase   →  .claude/codebase-map.md  ─┐
(per repo, once)    graphify-out/graph.json   │
                                              ├→ read automatically by any
promote-learnings →  ~/.claude/CLAUDE.md     ─┘   skill or session, because
(occasionally)       "## Learned patterns"        CLAUDE.md always loads
```

## Nothing lands in your repo

Both generated artifacts are added to your **global** gitignore, never the
project's. The pointer that makes them discoverable lives in your personal
`CLAUDE.md`. Teammates see no change, and `prime-codebase` verifies
`git status --porcelain` is clean before it finishes. The same goes for
`install.sh --seed`: it writes only inside `~/.claude/`, your personal
`CLAUDE.md` and a backup beside it.

If you'd rather share the map with your team, commit `.claude/codebase-map.md`
deliberately — just know it's generated and will go stale.

## Install

```bash
git clone https://github.com/<your-handle>/claude-context-kit.git
cd claude-context-kit && ./install.sh
```

Symlinks each skill into `~/.claude/skills/`, so `git pull` updates them in place.
Restart Claude Code after.

| Flag | Effect |
|---|---|
| `--copy` | Copy the skills instead of symlinking them. |
| `--force` | Replace anything already installed under the same skill name. |
| `--seed` | Also merge the working rules in `global-CLAUDE.md.seed` into `~/.claude/CLAUDE.md` (see below). |
| `--help` | Print the flag summary and exit. |

Set `CLAUDE_SKILLS_DIR` to install somewhere other than `~/.claude/skills`. The
script exits non-zero on any failure and never reports success for a step it
did not complete.

## Seed rules

`global-CLAUDE.md.seed` is a short list of project-agnostic working rules: ground
every claim in a tool result, never pass a secret on a command line, fix or file
a silent wrong outcome rather than "watching" it, and so on. Nothing in it names
a language, company, or repo. `./install.sh --seed` merges them into your
personal `~/.claude/CLAUDE.md` under a `## Working rules` heading, so they load
in every session.

The merge is by rule, not by heading, so it is safe to run against a file that
already has some of them. Each seed rule is compared with every top-level bullet
in your file and reported as one of:

```
  present  Ground every progress claim in a tool result from this session. Repor...
  add      Verify the shipped artifact against its source, never against itself. An exit code is not verification.
  similar  Never pass a secret as a command-line argument. It lands in argv, in ...
           existing: Never let a secret reach a command line: argv is world-readable via /...
           not added; merge by hand if the seed wording is better
```

- **present** — you already have the same text, ignoring case and punctuation.
  Nothing happens.
- **similar** — you have a reworded version (at least 40% of the rule's content
  words appear in one of your bullets, wherever it lives in the file). It is
  held back and shown to you, on the theory that a near-duplicate in a file that
  loads everywhere is worse than a missing rule. Merge it by hand if you want it.
  Re-running never rewrites a rule you already have; it only adds new ones.
- **add** — appended at the end of your `## Working rules` section, before any
  sub-heading, or as a new section at the end of the file if there is none.

Before writing, the script copies your file to `~/.claude/CLAUDE.md.bak.<timestamp>`
(with a `.1`, `.2` suffix if that name is taken), then writes the merged file
by renaming a temp file over the original, so a failed write cannot leave it
half-written. Bullets inside fenced code blocks or `<!-- -->` comments are
ignored, a symlinked `CLAUDE.md` is written through the link, and its
permissions are kept. If anything fails, the backup path is printed and the
script exits non-zero. Re-running is a no-op once everything is present.

The merge is tested end to end in throwaway home directories:

```bash
bash tests/seed-merge.sh
```

## Requirements

| | `prime-codebase` | `promote-learnings` |
|---|---|---|
| Claude Code | required | required |
| [Graphify](https://github.com/Graphify-Labs/graphify) | required | — |
| Python 3.10+ | required (for Graphify) | required (reads JSONL) |
| [gstack](https://github.com/garrytan/gstack) | not required | **required** |

Graphify:

```bash
pip install graphifyy && graphify install
# macOS with a managed Python:
pipx install graphifyy && graphify install
```

`prime-codebase` uses Graphify's code path only — deterministic tree-sitter AST
parsing, no LLM and no network. It explicitly avoids setting an LLM API key so
the run stays local. Verified against Graphify 0.9.53 on TypeScript/TSX including
Next.js `@/*` path aliases.

`promote-learnings` reads gstack's per-project records at
`~/.gstack/projects/<slug>/`. Without gstack there's nothing for it to read.

`install.sh`, with or without `--seed`, needs only bash 3.2+ and awk, so it runs
on a stock macOS or Linux shell. The atomic write uses `readlink -f` (macOS
12.3+ or Linux) and falls back to writing in place without it. The merge has
been exercised on BSD awk; gawk and mawk use only constructs they share with it
but were not run directly.

## A note on what gets promoted

`promote-learnings` writes into a file that loads in **every** repo you open —
including other clients' work. It has a mandatory genericization step: client and
product names, internal component names, paths, hostnames and people are stripped
before anything is proposed, and every line is shown to you in its final wording
before it's written. If a lesson can't survive that and still be useful, it's
dropped. Worth checking the first few times anyway.

## Usage

```
/prime-codebase        # in a repo you're new to, or when the map is stale
/promote-learnings     # after shipping something, or at a retro
```

`prime-codebase` is safe to re-run; it rebuilds the graph and rewrites the map.

[WORKFLOW.md](WORKFLOW.md) shows where these sit in a feature loop and a bug
loop alongside gstack.

## Credits

- [gstack](https://github.com/garrytan/gstack) by Garry Tan — MIT
- [Graphify](https://github.com/Graphify-Labs/graphify) by Graphify Labs

Neither project is affiliated with this one. MIT licensed; see LICENSE.
