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
`git status --porcelain` is clean before it finishes.

If you'd rather share the map with your team, commit `.claude/codebase-map.md`
deliberately — just know it's generated and will go stale.

## Install

```bash
git clone https://github.com/<your-handle>/claude-context-kit.git
cd claude-context-kit && ./install.sh
```

Symlinks each skill into `~/.claude/skills/`, so `git pull` updates them in place.
Use `./install.sh --copy` if you'd rather have copies. Restart Claude Code after.

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

## Credits

- [gstack](https://github.com/garrytan/gstack) by Garry Tan — MIT
- [Graphify](https://github.com/Graphify-Labs/graphify) by Graphify Labs

Neither project is affiliated with this one. MIT licensed; see LICENSE.
