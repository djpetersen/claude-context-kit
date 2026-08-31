---
name: promote-learnings
description: Review what gstack recorded on this project and promote the genuinely general lessons into the user's personal ~/.claude/CLAUDE.md so they apply in every future repo. Use at the end of a feature, after /ship or /retro, or when asked "what have we learned generally".
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion, Grep
---

# Promote learnings

gstack records learnings and decisions per project. This is the missing step:
deciding which of them are portable, and moving those up a level.

- **Project level** (gstack already does this): `~/.gstack/projects/<slug>/learnings.jsonl` and `decisions.jsonl`
- **Cross-project** (this skill): a managed section in `~/.claude/CLAUDE.md`, which loads in every repo

## Trigger

- "promote learnings", "what have we learned generally", "roll up the lessons"
- End of a feature or sprint, after `/ship` or `/retro`
- Never automatically. Promotion always requires the user to approve each line.

## Steps

### 1. Locate this project's records

```bash
SLUG="$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null || true)"
[ -n "$SLUG" ] || SLUG="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
ROOT="${GSTACK_HOME:-$HOME/.gstack}/projects/$SLUG"
echo "slug: $SLUG"
ls -la "$ROOT" 2>/dev/null
wc -l "$ROOT/learnings.jsonl" "$ROOT/decisions.jsonl" 2>/dev/null
```

If neither file exists, say plainly that gstack has recorded nothing on this
project yet, and stop. Never invent learnings to fill the gap.

### 2. Read them

```bash
python3 - "$ROOT" <<'PY'
import sys, json, pathlib
root = pathlib.Path(sys.argv[1])
for fn in ('learnings.jsonl', 'decisions.jsonl'):
    p = root / fn
    if not p.exists(): continue
    print(f"--- {fn} ---")
    for line in p.read_text().splitlines():
        try: d = json.loads(line)
        except Exception: continue
        body = d.get('insight') or d.get('decision') or ''
        print(f"[{d.get('type') or d.get('scope','?')}] {d.get('key','')}: {body}")
PY
```

Also read the existing `## Learned patterns` section of `~/.claude/CLAUDE.md`
so nothing already promoted gets proposed again.

### 3. Classify each item

- **Portable** — true of the framework, language, tool or the user's own working
  style regardless of repo. "Server components can't use hooks." "Check
  tsconfig path aliases before a bulk import refactor."
- **Project-specific** — names this repo's files, components, domain or people.
  Stays where it is.

When in doubt, project-specific. The global file must stay short to stay read.

### 4. Genericize before proposing — MANDATORY

A promoted line loads in **every** repo, including other clients' work. Before
proposing any line, strip:

- client, employer and product names
- repo-specific paths, component names and internal terminology
- anything resembling a credential, URL, hostname or key
- named people

If a lesson cannot survive that stripping and still be useful, it is not
portable — drop it. Never propose a line you have not rewritten generically.

### 5. Ask

Present the surviving candidates with `AskUserQuestion` (multiSelect), each
shown in its **final genericized wording**, so the user approves the exact text
that will be written. No more than 8 at a time.

### 6. Write

Back the file up first — this is the user's global memory file, and a bad edit
affects every repo they open:

```bash
[ -f ~/.claude/CLAUDE.md ] && cp ~/.claude/CLAUDE.md ~/.claude/CLAUDE.md.bak
```

Then append approved lines to the managed section of `~/.claude/CLAUDE.md`:

```markdown
## Learned patterns

<!-- managed by promote-learnings — one line per lesson, newest last -->
- (2026-09-02) Check tsconfig path aliases before any bulk import refactor.
```

One line each, declarative or imperative, dated, no rationale paragraphs.
Never rewrite or delete an existing line without asking first.

### 7. Prune

If the section exceeds 40 lines, do not simply append. Show the user the oldest
and most overlapping lines and offer to merge or drop them. A global file
nobody reads is worse than no global file.

## Verification

1. Re-read `~/.claude/CLAUDE.md`: it parses as clean markdown with exactly one
   `## Learned patterns` heading.
2. Grep the newly promoted lines for leaked identifiers — client and product
   names, internal component names, paths, hostnames. Remove any that survived
   and tell the user which.
3. Confirm the project's `learnings.jsonl` is unchanged — promotion copies
   upward, it never consumes the project record.
4. Report: count promoted, count left at project level, and the new line count
   of the global section.
