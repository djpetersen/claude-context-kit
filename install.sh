#!/usr/bin/env bash
# Install these skills into ~/.claude/skills/.
#
#   ./install.sh            symlink (default) — `git pull` then updates them in place
#   ./install.sh --copy     copy instead of symlinking
#   ./install.sh --force    replace anything already installed under the same name
#   ./install.sh --seed     also merge the project-agnostic working rules from
#                           global-CLAUDE.md.seed into ~/.claude/CLAUDE.md
#
# Env: CLAUDE_SKILLS_DIR overrides the install location (default ~/.claude/skills).
set -euo pipefail

SEED_WORK=""
trap 'if [ -n "$SEED_WORK" ]; then rm -rf "$SEED_WORK"; fi' EXIT

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/skills"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MODE=symlink
FORCE=0
SEED=0

for arg in "$@"; do
  case "$arg" in
    --copy)   MODE=copy ;;
    --force)  FORCE=1 ;;
    --seed)   SEED=1 ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install.sh: unknown option '$arg' (try --help)" >&2; exit 2 ;;
  esac
done

[ -d "$SRC" ] || { echo "install.sh: no skills/ directory beside this script" >&2; exit 1; }
shopt -s nullglob
dirs=("$SRC"/*/)
(( ${#dirs[@]} )) || { echo "install.sh: skills/ is empty" >&2; exit 1; }

mkdir -p "$DEST"
installed=0
for dir in "${dirs[@]}"; do
  dir="${dir%/}"                       # strip trailing slash; a symlink to "path/" is fragile
  name="$(basename "$dir")"
  target="$DEST/$name"

  [ -f "$dir/SKILL.md" ] || { echo "  skip    $name (no SKILL.md)"; continue; }

  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$FORCE" = 1 ]; then
      rm -rf "$target"
    elif [ -L "$target" ] && [ ! -e "$target" ]; then
      echo "  broken  $name -> $(readlink "$target")  (re-run with --force to replace)"
      continue
    else
      echo "  skip    $name (already installed; --force to replace)"
      continue
    fi
  fi

  if [ "$MODE" = copy ]; then cp -R "$dir" "$target"; echo "  copied  $name"
  else ln -s "$dir" "$target"; echo "  linked  $name -> $dir"; fi
  installed=$((installed + 1))
done

echo
if (( installed )); then
  echo "Installed $installed skill(s) into $DEST."
  echo "Restart Claude Code, then try /prime-codebase or /promote-learnings."
else
  echo "Nothing installed. Use --force to replace existing entries."
fi

# --- --seed: merge working rules into ~/.claude/CLAUDE.md --------------------
#
# The seed is a list of "- " bullets. Each bullet is one rule. The merge is by
# rule content, not by heading: a rule is skipped if the target already has it
# verbatim, and held back (reported, not added) if the target has something
# that reads like a reworded version of it. Only rules with no match are
# appended, under the target's copy of the seed's "## " heading if there is
# one. The target is backed up before it is written.

SEED_HEADING_DEFAULT='## Working rules'   # used only if the seed file has no "## " heading
SEED_SIMILARITY=0.4   # share of a seed rule's content words found in one existing rule

# Print the top-level bullets ("- ", "* " or "+ " at column 0) of a markdown
# file, one rule per line, with wrapped continuation lines joined by a single
# space, CRs dropped and tabs flattened to spaces (the classifier's output is
# tab-separated). Fenced code blocks and <!-- --> comments are skipped: a
# "- " inside one is code or commented out, not a live rule.
extract_rules() {
  awk '
    function flush() { if (inrule) { gsub(/\t/, " ", cur); print cur }; inrule = 0; cur = "" }
    { sub(/\r$/, "") }
    !incomment && /<!--/           { flush(); incomment = 1 }
    incomment                      { if (/-->/) incomment = 0; next }
    /^(```|~~~)/                   { flush(); infence = !infence; next }
    infence                        { next }
    /^[-*+] /                      { flush(); inrule = 1; cur = substr($0, 3); next }
    /^[ \t]+[^ \t]/ && inrule      { line = $0; sub(/^[ \t]+/, "", line); cur = (cur == "") ? line : cur " " line; next }
                                   { flush() }
    END                            { flush() }
  ' "$1"
}

# Print the raw lines (bullet plus its continuation lines) of the Nth bullet,
# counting bullets exactly as extract_rules does.
seed_block() {
  awk -v n="$2" '
    !incomment && /<!--/ { if (k == n) exit; incomment = 1 }
    incomment    { if (/-->/) incomment = 0; next }
    /^(```|~~~)/ { if (k == n) exit; infence = !infence; next }
    infence      { next }
    /^[-*+] /    { k++ }
    k == n       { if (/^[-*+] / || /^[ \t]+[^ \t]/) print; else exit }
  ' "$1"
}

# For each rule in file 2 (the seed) report, against the rules in file 1 (the
# target), one tab-separated line: verdict, index, existing rule, seed rule.
#   present <i> <existing rule> <seed rule>   identical after normalisation
#   similar <i> <existing rule> <seed rule>   >= SEED_SIMILARITY of the seed
#                                             rule's content words appear in
#                                             that existing rule
#   absent  -   -               <seed rule>   ("-" placeholders keep the fields aligned)
# Content words are lowercase alphabetic runs of four or more letters, so
# dates, punctuation and short function words do not count as overlap. The
# denominator is always the seed rule, so a short existing bullet cannot
# match by accident.
classify_rules() {
  awk -v thr="$SEED_SIMILARITY" '
    function norm(s) {
      s = tolower(s); gsub(/[^a-z]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); return s
    }
    function words(s, out,   n, i, parts) {
      delete out
      n = split(s, parts, " ")
      for (i = 1; i <= n; i++) if (length(parts[i]) >= 4) out[parts[i]] = 1
    }
    FILENAME == ARGV[1] { tn++; traw[tn] = $0; tnorm[tn] = norm($0); next }
    {
      sn = norm($0); exact = 0; best = 0; bi = 0
      words(sn, a)
      for (i = 1; i <= tn; i++) {
        if (sn != "" && tnorm[i] == sn) { exact = i; break }
        words(tnorm[i], b)
        na = 0; ni = 0
        for (w in a) { na++; if (w in b) ni++ }
        score = (na > 0) ? ni / na : 0
        if (score > best) { best = score; bi = i }
      }
      if (exact)            print "present\t" exact "\t" traw[exact] "\t" $0
      else if (best >= thr) print "similar\t" bi "\t" traw[bi] "\t" $0
      else                  print "absent\t-\t-\t" $0   # placeholders: read collapses adjacent tabs
    }
  ' "$1" "$2"
}

# Insert the lines of file 2 into the SEED_HEADING section of file 1 (matched
# case-insensitively, outside fences and comments), after that section's own
# top-level content and before any sub-heading; or append a new section if the
# heading is absent. Inserted lines take the file's line ending. Writes to stdout.
insert_rules() {
  awk -v heading="$SEED_HEADING" -v block="$2" '
    function skip(i) {   # true while line i is inside a fence or an HTML comment
      if (!incomment && lines[i] ~ /<!--/) incomment = 1
      if (incomment) { if (lines[i] ~ /-->/) incomment = 0; return 1 }
      if (lines[i] ~ /^(```|~~~)/) { infence = !infence; return 1 }
      return infence
    }
    BEGIN { while ((getline l < block) > 0) nb[++n] = l; close(block); want = tolower(heading) }
    { lines[NR] = $0 }
    END {
      h = 0; infence = 0; incomment = 0
      for (i = 1; i <= NR; i++) {
        if (skip(i)) continue
        l = tolower(lines[i]); sub(/[ \t\r]+$/, "", l); gsub(/[ \t]+/, " ", l)
        if (l == want) { h = i; break }
      }
      eol = (NR > 0 && lines[1] ~ /\r$/) ? "\r" : ""
      if (h) {
        e = NR; infence = 0; incomment = 0
        for (i = h + 1; i <= NR; i++) {
          if (skip(i)) continue
          if (lines[i] ~ /^#+ /) { e = i - 1; break }
        }
        while (e > h && lines[e] ~ /^[ \t\r]*$/) e--
        for (i = 1; i <= e; i++) print lines[i]
        if (e == h) print eol
        for (i = 1; i <= n; i++) print nb[i] eol
        for (i = e + 1; i <= NR; i++) print lines[i]
      } else {
        for (i = 1; i <= NR; i++) print lines[i]
        if (NR > 0 && lines[NR] !~ /^[ \t\r]*$/) print eol
        print heading eol
        print eol
        for (i = 1; i <= n; i++) print nb[i] eol
      }
    }
  ' "$1"
}

trunc() { local s="$1" w=72; (( ${#s} > w )) && s="${s:0:w-3}..."; printf '%s' "$s"; }

seed_rules() {
  local seed_src="$HERE/global-CLAUDE.md.seed"
  local dest_md="$HOME/.claude/CLAUDE.md"
  [ -f "$seed_src" ] || { echo "install.sh: global-CLAUDE.md.seed not found" >&2; return 1; }
  SEED_HEADING="$(grep -m1 '^## ' "$seed_src" | sed 's/[[:space:]]*$//' || true)"
  SEED_HEADING="${SEED_HEADING:-$SEED_HEADING_DEFAULT}"

  local work; work="$(mktemp -d)"
  SEED_WORK="$work"   # removed by the EXIT trap at the top of the script; RETURN traps do not fire on errexit in bash 3.2

  extract_rules "$seed_src" > "$work/seed"
  if [ -f "$dest_md" ]; then extract_rules "$dest_md" > "$work/target"; else : > "$work/target"; fi
  [ -s "$work/seed" ] || { echo "install.sh: no rules found in $seed_src" >&2; return 1; }

  classify_rules "$work/target" "$work/seed" > "$work/verdicts"

  echo
  echo "Seed rules vs $dest_md:"
  local i=0 added=0 present=0 similar=0 verdict existing rule
  local total; total="$(wc -l < "$work/seed" | tr -d ' ')"
  : > "$work/block"
  while IFS=$'\t' read -r verdict _ existing rule; do
    i=$((i + 1))
    case "$verdict" in
      present)
        present=$((present + 1))
        echo "  present  $(trunc "$rule")" ;;
      similar)
        similar=$((similar + 1))
        echo "  similar  $(trunc "$rule")"
        echo "           existing: $(trunc "$existing")"
        echo "           not added; merge by hand if the seed wording is better" ;;
      absent)
        added=$((added + 1))
        seed_block "$seed_src" "$i" >> "$work/block"
        echo "  add      $rule" ;;
      *)
        echo "install.sh: unexpected classifier output: $verdict" >&2; return 1 ;;
    esac
  done < "$work/verdicts"
  if [ "$i" != "$total" ]; then
    echo "install.sh: classified $i of $total seed rules; not touching $dest_md" >&2
    return 1
  fi

  echo
  if (( added == 0 )); then
    echo "Nothing to add: $present present, $similar similar. $dest_md not touched."
    return 0
  fi

  mkdir -p "$HOME/.claude"
  local backup="" n=0
  if [ -f "$dest_md" ]; then
    backup="$dest_md.bak.$(date +%Y%m%d%H%M%S)"
    while [ -e "$backup" ]; do n=$((n + 1)); backup="$dest_md.bak.$(date +%Y%m%d%H%M%S).$n"; done
    cp -p "$dest_md" "$backup"
    echo "Backup: $backup"
  else
    : > "$dest_md"
  fi
  insert_rules "$dest_md" "$work/block" > "$work/new"
  local before after
  before="$(extract_rules "$dest_md" | wc -l | tr -d ' ')"
  after="$(extract_rules "$work/new" | wc -l | tr -d ' ')"
  if [ "$after" != "$((before + added))" ]; then
    echo "install.sh: merged file has $after rules, expected $((before + added)); not touching $dest_md" >&2
    return 1
  fi
  # Replace atomically: write beside the (symlink-resolved) target, then rename.
  local real="$dest_md" tmp
  if [ -L "$dest_md" ]; then real="$(readlink -f "$dest_md" 2>/dev/null || true)"; fi
  if [ -n "$real" ] && tmp="$(mktemp "$(dirname "$real")/.CLAUDE.md.XXXXXX" 2>/dev/null)"; then
    cp -p "$real" "$tmp" && cat "$work/new" > "$tmp" && mv -f "$tmp" "$real" \
      || { rm -f "$tmp"; echo "install.sh: write failed; $dest_md unchanged${backup:+, backup at $backup}" >&2; return 1; }
  else
    cat "$work/new" > "$dest_md" \
      || { echo "install.sh: write failed${backup:+; restore from $backup}" >&2; return 1; }
  fi
  echo "Added $added rule(s) to $dest_md ($present already present, $similar similar and held back)."
  echo "These load in every project. Read them once and prune anything you disagree with."
}

if [ "$SEED" = 1 ]; then seed_rules; fi
