#!/usr/bin/env bash
# Install these skills into ~/.claude/skills/.
#
#   ./install.sh            symlink (default) — `git pull` then updates them in place
#   ./install.sh --copy     copy instead of symlinking
#   ./install.sh --force    replace anything already installed under the same name
#
# Env: CLAUDE_SKILLS_DIR overrides the install location (default ~/.claude/skills).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skills"
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MODE=symlink
FORCE=0

for arg in "$@"; do
  case "$arg" in
    --copy)   MODE=copy ;;
    --force)  FORCE=1 ;;
    -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
