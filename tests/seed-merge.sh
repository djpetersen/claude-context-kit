#!/usr/bin/env bash
# Tests for `install.sh --seed`. Run: bash tests/seed-merge.sh
# Every scenario gets its own throwaway HOME; the real ~/.claude is never touched.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED="$REPO/global-CLAUDE.md.seed"
SEED_COUNT="$(grep -c '^- ' "$SEED")"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

pass=0; fail=0
ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); echo "FAIL: $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/      /'; }

# new_home <name>  -> prints a fresh HOME path with .claude/ created
new_home() { local h="$SANDBOX/$1"; mkdir -p "$h/.claude"; printf '%s' "$h"; }
# seed <home>      -> runs the installer with --seed against that HOME; prints combined output
seed() { HOME="$1" CLAUDE_SKILLS_DIR="$1/skills" "$REPO/install.sh" --seed 2>&1; }
rules() { grep -c '^- ' "$1" || true; }
target() { printf '%s/.claude/CLAUDE.md' "$1"; }

# --- no CLAUDE.md at all: whole seed lands under a new heading, no backup ----
h="$(new_home nofile)"; rm -rf "$h/.claude"; mkdir -p "$h"
out="$(seed "$h")"
[ "$(rules "$(target "$h")")" = "$SEED_COUNT" ] && ok || bad "no file: expected $SEED_COUNT rules" "$out"
[ "$(head -1 "$(target "$h")")" = "## Working rules" ] && ok || bad "no file: heading first"
[ "$(ls "$h/.claude" | wc -l | tr -d ' ')" = 1 ] && ok || bad "no file: no backup expected"

# --- empty CLAUDE.md --------------------------------------------------------
h="$(new_home empty)"; : > "$(target "$h")"
out="$(seed "$h")"
[ "$(rules "$(target "$h")")" = "$SEED_COUNT" ] && ok || bad "empty file" "$out"

# --- partial overlap: verbatim rule is present, reworded rule is held back ---
h="$(new_home partial)"
{
  echo '# Mine'; echo; echo '## Learned patterns'; echo
  echo '- (2026-01-01) Never let a secret reach a command line: argv is world-readable via /proc and lands in shell history.'
  echo; echo '## Working rules'; echo
  sed -n '/^- Ground every progress claim/,/measured one\.$/p' "$SEED"
  echo '- Reviews and audits run their specialist and adversarial subagents. Spawning them is expected and does not need permission each time.'
  echo; echo '## After'; echo; echo '- after bullet'
} > "$(target "$h")"
out="$(seed "$h")"
echo "$out" | grep -q "Added $((SEED_COUNT - 3)) rule(s).*1 already present, 2 similar" && ok || bad "partial: counts" "$out"
echo "$out" | grep -q '^  similar  Never pass a secret' && ok || bad "partial: cross-section similar match" "$out"
echo "$out" | grep -q '^  add      Verify the shipped artifact against its source, never against itself. An exit code is not verification.$' && ok || bad "partial: add line must show the full rule text" "$out"
grep -q '^- after bullet' "$(target "$h")" && ok || bad "partial: later section intact"
after_line="$(awk '/^## After/{print NR; exit}' "$(target "$h")")"
last_rule_line="$(awk '/^- Runs are autonomous/{print NR}' "$(target "$h")")"
[ "$last_rule_line" -lt "$after_line" ] && ok || bad "partial: rules inserted inside Working rules section"
ls "$h/.claude"/CLAUDE.md.bak.* >/dev/null 2>&1 && ok || bad "partial: backup written"
out2="$(seed "$h")"
echo "$out2" | grep -q "Nothing to add: $((SEED_COUNT - 2)) present, 2 similar" && ok || bad "partial: idempotent" "$out2"

# --- heading with trailing whitespace, and CRLF line endings ----------------
h="$(new_home ws)"; printf '## Working rules \n\n- x\n\n## Z\n' > "$(target "$h")"
seed "$h" >/dev/null
[ "$(grep -c '^## Working rules' "$(target "$h")")" = 1 ] && ok || bad "trailing-space heading duplicated"
h="$(new_home crlf)"; printf '## Working rules\r\n\r\n- existing\r\n' > "$(target "$h")"
seed "$h" >/dev/null
[ "$(grep -c '^## Working rules' "$(target "$h")")" = 1 ] && ok || bad "CRLF heading duplicated"

# --- heading inside an HTML comment or a fence is not the section --------------
h="$(new_home hidden)"
printf '<!--\n## Working rules\n-->\n\n```\n## Working rules\n```\n\n# Global\n\n- keep\n' > "$(target "$h")"
seed "$h" >/dev/null
[ "$(grep -c '^## Working rules' "$(target "$h")")" = 3 ] && ok || bad "hidden headings: expected a new real section appended"
[ "$(tail -1 "$(target "$h")" | cut -c1-6)" = "  reco" ] && ok || bad "hidden headings: rules should be at end of file"

# --- case-insensitive heading, sub-heading is a boundary, CRLF endings kept ----
h="$(new_home h3)"
printf '## Working Rules\n\n- old\n\n### Exceptions\n\n- exc\n' > "$(target "$h")"
seed "$h" >/dev/null
[ "$(grep -c -i '^## Working rules' "$(target "$h")")" = 1 ] && ok || bad "case-insensitive heading not matched"
[ "$(awk '/^### Exceptions/{print NR;exit}' "$(target "$h")")" -gt 20 ] && ok || bad "rules not inserted before ### sub-heading"
h="$(new_home crlf2)"; printf '## Working rules\r\n\r\n- existing\r\n' > "$(target "$h")"
seed "$h" >/dev/null
[ "$(grep -c $'\r$' "$(target "$h")")" = "$(wc -l < "$(target "$h")" | tr -d ' ')" ] && ok || bad "CRLF file got LF lines"

# --- fenced code block under the heading is not a section boundary -----------
h="$(new_home fence)"
printf '## Working rules\n\n- rule one\n\n```bash\n# a comment\n- not a rule\n```\n\n## Z\n' > "$(target "$h")"
out="$(seed "$h")"
echo "$out" | grep -q "Added $SEED_COUNT rule" && ok || bad "fence: '- not a rule' inside fence counted as a rule" "$out"
awk '/^```/{f=!f} f && /^- Ground every/{bad=1} END{exit bad}' "$(target "$h")" && ok || bad "fence: rule inserted inside code block"

# --- a rule inside an HTML comment is commented out, not present -------------
h="$(new_home comment)"
{ echo '## Working rules'; echo; echo '<!--'; sed -n '/^- Ground every progress claim/,/measured one\.$/p' "$SEED"; echo '-->'; } > "$(target "$h")"
out="$(seed "$h")"
echo "$out" | grep -q "Added $SEED_COUNT rule" && ok || bad "commented-out rule reported as present" "$out"
[ -z "$(ls -A "$h/.claude" | grep '^\.CLAUDE\.md\.')" ] && ok || bad "temp file left beside target"

# --- '* ' bullets in the target still count as existing rules ----------------
h="$(new_home star)"
{ echo '## Working rules'; echo; sed -n '/^- Ground every progress claim/,/measured one\.$/p' "$SEED" | sed '1s/^- /* /'; } > "$(target "$h")"
out="$(seed "$h")"
echo "$out" | grep -q '1 already present' && ok || bad "star bullet not recognised" "$out"

# --- symlinked target keeps its link and mode ---------------------------------
h="$(new_home link)"; mkdir -p "$h/dot"; printf '## Working rules\n\n- x\n' > "$h/dot/c.md"; chmod 600 "$h/dot/c.md"
ln -s ../dot/c.md "$(target "$h")"
seed "$h" >/dev/null
[ -L "$(target "$h")" ] && ok || bad "symlink replaced by a regular file"
[ "$(stat -f %Lp "$h/dot/c.md" 2>/dev/null || stat -c %a "$h/dot/c.md")" = 600 ] && ok || bad "mode 600 not preserved"

# --- two writes in one second keep two backups --------------------------------
h="$(new_home bk)"; printf '# Mine\n' > "$(target "$h")"
seed "$h" >/dev/null
sed -i.orig '/^- Runs are autonomous/,/as you go\.$/d' "$(target "$h")"; rm -f "$(target "$h").orig"
seed "$h" >/dev/null
[ "$(ls "$h/.claude"/CLAUDE.md.bak.* | wc -l | tr -d ' ')" = 2 ] && ok || bad "second backup overwrote the first"

# --- similarity threshold boundary (unit) -------------------------------------
fns="$SANDBOX/fns.sh"; sed -n '/^SEED_HEADING_DEFAULT=/,/^seed_rules()/p' "$REPO/install.sh" | sed '$d' > "$fns"
# shellcheck disable=SC1090
source "$fns"
printf -- '- alpha bravo charlie delta echo\n' > "$SANDBOX/s"
printf -- '- alpha bravo xxxxx yyyyy zzzzz\n' > "$SANDBOX/t40"   # 2 of 5 content words -> 0.40 -> similar
printf -- '- alpha xxxxx yyyyy zzzzz wwwww\n' > "$SANDBOX/t20"   # 1 of 5 -> 0.20 -> absent
[ "$(classify_rules "$SANDBOX/t40" "$SANDBOX/s" | cut -f1)" = similar ] && ok || bad "threshold: 0.40 should be similar"
[ "$(classify_rules "$SANDBOX/t20" "$SANDBOX/s" | cut -f1)" = absent ]  && ok || bad "threshold: 0.20 should be absent"
printf -- '- 2026-01-01\n' > "$SANDBOX/digits"; printf -- '- 2025-02-02\n' > "$SANDBOX/digits2"
[ "$(classify_rules "$SANDBOX/digits2" "$SANDBOX/digits" | cut -f1)" = absent ] && ok || bad "empty-normalised rules must not match as present"

# --- classifier failure must not report success -------------------------------
h="$(new_home broken)"; printf '# Mine\n' > "$(target "$h")"
broken="$SANDBOX/broken-install.sh"
sed 's/^classify_rules() {$/classify_rules() { echo "awk: boom" >\&2; return 2; }\nclassify_rules_unused() {/' "$REPO/install.sh" > "$broken"
mkdir -p "$SANDBOX/brokenrepo"; cp "$broken" "$SANDBOX/brokenrepo/install.sh"; chmod +x "$SANDBOX/brokenrepo/install.sh"
cp -R "$REPO/skills" "$SEED" "$SANDBOX/brokenrepo/"
rc=0; out="$(HOME="$h" CLAUDE_SKILLS_DIR="$h/skills" "$SANDBOX/brokenrepo/install.sh" --seed 2>&1)" || rc=$?
if [ "$rc" != 0 ] && ! echo "$out" | grep -q 'Nothing to add\|Added'; then ok; else bad "classifier failure reported as success (rc=$rc)" "$out"; fi
[ "$(cat "$(target "$h")")" = '# Mine' ] && ok || bad "classifier failure modified the target"

# --- missing seed file fails --------------------------------------------------
mkdir -p "$SANDBOX/noseed"; cp -R "$REPO/skills" "$REPO/install.sh" "$SANDBOX/noseed/"
h="$(new_home noseed)"
rc=0; HOME="$h" CLAUDE_SKILLS_DIR="$h/skills" "$SANDBOX/noseed/install.sh" --seed >/dev/null 2>&1 || rc=$?
[ "$rc" = 1 ] && ok || bad "missing seed should exit 1 (got $rc)"

echo "seed-merge: $pass passed, $fail failed"
[ "$fail" = 0 ]
