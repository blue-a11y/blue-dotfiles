#!/bin/bash
# Explicit, symmetric Git synchronization. No force pushes, resets or hook bypasses.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd -P)"
cd "$REPO_DIR"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'HELP'
Usage: ./sync.sh [status | sync] [--home ABSOLUTE_PATH]

status  Show local Git state without fetching, staging, committing or pushing (default).
sync    Fetch the configured upstream, save local configuration changes, merge and push.

Both computers must use branches with the same name and the same shared upstream.
Existing staged changes or merge conflicts require manual handling before synchronization.
HELP
}

ACTION=status
TARGET_HOME="$HOME"
ACTION_SET=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    status|sync)
      [ "$ACTION_SET" = false ] || fail 'Expected a single action: status or sync'
      ACTION="$1"; ACTION_SET=true ;;
    --home)
      [ "$#" -ge 2 ] || fail '--home requires an absolute path'
      TARGET_HOME="$2"; shift ;;
    *) fail "Unknown action or option: $1" ;;
  esac
  shift
done
case "$TARGET_HOME" in /*) ;; *) fail '--home requires an absolute path' ;; esac
[ "$(git rev-parse --show-toplevel)" = "$REPO_DIR" ] || fail 'The script must live at the repository root'
if [ "$ACTION" = status ]; then
  git status --short --branch
  if ! git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null; then
    printf 'No upstream configured. Publish this branch before using sync.\n'
  fi
  exit 0
fi

BRANCH="$(git symbolic-ref --quiet --short HEAD)" || fail 'A named branch is required; HEAD is detached'
REMOTE="$(git config --get "branch.$BRANCH.remote" || true)"
MERGE_REF="$(git config --get "branch.$BRANCH.merge" || true)"
[ -n "$REMOTE" ] && [ "$REMOTE" != . ] && [ -n "$MERGE_REF" ] || fail 'No shared remote upstream configured for this branch'
case "$MERGE_REF" in refs/heads/*) ;; *) fail 'Upstream must be a remote branch' ;; esac
REMOTE_BRANCH="${MERGE_REF#refs/heads/}"
[ "$BRANCH" = "$REMOTE_BRANCH" ] || fail 'Local and upstream branch names must match; check the intended shared branch'

for operation in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD rebase-merge rebase-apply; do
  [ ! -e "$(git rev-parse --git-path "$operation")" ] || fail "Unfinished Git operation ($operation). Resolve it before synchronization."
done
git diff --cached --quiet || fail 'Existing staged changes must be committed or unstaged manually first'

# Configuration files outside this checkout must not be mistaken for synchronized
# edits. This also detects an application replacing a file symlink during a save.
check_links() {
  local application source relative extra
  while IFS=$'\t' read -r application source relative extra || [ -n "$application" ]; do
    case "$application" in ''|\#*) continue ;; esac
    [ "$TARGET_HOME/$relative" -ef "$REPO_DIR/$source" ] || fail "Configuration link is not active: $TARGET_HOME/$relative. Compare and preserve that local file before running ./link.sh --apply."
  done < "$REPO_DIR/links.tsv"
}
check_links

LOCK_DIR="$(git rev-parse --git-path dotfiles-sync.lock)"
mkdir "$LOCK_DIR" 2>/dev/null || fail "Another synchronization may be running. Inspect $LOCK_DIR before retrying."
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

managed() {
  case "$1" in
    .gitignore|AGENTS.md|README.md|links.tsv|link.sh|sync.sh|tests/test_*.py) return 0 ;;
    ghostty/config|ghostty/themes/*|vim/vimrc) return 0 ;;
    vscode/argv.json|vscode/custom.css|vscode/bin/vim-im-force-abc) return 0 ;;
    zed/settings.json|zed/keymap.json|zed/tasks.json|zed/extensions.json|zed/snippets/*.json|zed/themes/*.json) return 0 ;;
    nvim/*.lua|nvim/*.json|nvim/*.toml|nvim/LICENSE|nvim/README.md|nvim/.gitignore) return 0 ;;
    kero/app.json) return 0 ;;
    claude-code/CLAUDE.md|claude-code/settings.json) return 0 ;;
    *) return 1 ;;
  esac
}

check_portable() {
  local path="$1"
  [ ! -L "$path" ] || fail "Repository sources must not be external symlinks: $path"
  [ -f "$path" ] || return 0
  case "$path" in *.json|*.code-snippets|*.toml|ghostty/config) ;; *) return 0 ;; esac
  if LC_ALL=C grep -Eiq '"(api[_-]?key|access[_-]?token|auth[_-]?token|authorization|password|client[_-]?secret)"[[:space:]]*:[[:space:]]*"[^"]+"|"crash-reporter-id"[[:space:]]*:' "$path"; then
    fail "Private or machine-specific field detected in $path; keep it local before syncing"
  fi
  case "$path" in
    *.toml)
      local toml_private_pattern="^[[:space:]]*[\"']?(api[_-]?key|access[_-]?token|auth[_-]?token|authorization|password|client[_-]?secret)[\"']?[[:space:]]*="
      if LC_ALL=C grep -Eiq "$toml_private_pattern" "$path"; then
        fail "Private field detected in $path; keep it local before syncing"
      fi
      ;;
  esac
  if LC_ALL=C grep -Eq '/Users/[^/[:space:]"]+/' "$path"; then
    fail "Machine-specific home path detected in $path; use a portable setting before syncing"
  fi
}

check_current_configs() {
  local path
  while IFS= read -r -d '' path; do
    if managed "$path"; then check_portable "$path"; fi
  done < <(git ls-files -z)
}
check_current_configs

CHANGES=()
while IFS= read -r -d '' path; do
  managed "$path" || fail "Unmanaged change: $path. Review it with Git manually; it will not be auto-committed."
  check_portable "$path"
  CHANGES+=("$path")
done < <(git ls-files --modified --deleted --others --exclude-standard -z)

# Fetch before creating a local commit so an offline/auth failure leaves the index untouched.
git fetch "$REMOTE" "$MERGE_REF" || fail 'Fetch failed; local edits remain unchanged'
FETCHED_COMMIT="$(git rev-parse --verify FETCH_HEAD)"
check_links
check_current_configs
if [ "${#CHANGES[@]}" -gt 0 ]; then
  # Recheck after fetching in case an application updated a configuration meanwhile.
  for path in "${CHANGES[@]}"; do check_portable "$path"; done
  git add -A -- "${CHANGES[@]}"
  if ! git diff --cached --quiet; then
    git commit -m 'chore(dotfiles): sync configuration' || fail 'Commit failed; inspect the preserved working tree and index'
  fi
fi
[ -z "$(git status --porcelain)" ] || fail 'The checkout changed during synchronization; inspect it before retrying'
if ! git merge --no-edit "$FETCHED_COMMIT"; then
  fail 'Merge conflict or merge failure. Both histories are preserved. Resolve conflicts, git add the resolved files, git commit, then rerun ./sync.sh sync.'
fi
check_links
check_current_configs
[ -z "$(git status --porcelain)" ] || fail 'The checkout changed during synchronization; inspect it before retrying'
git push "$REMOTE" "HEAD:$MERGE_REF" || fail 'Push rejected or unavailable. Local commits are preserved; rerun sync to fetch and combine any newer remote changes.'
printf '\nSynchronized %s with %s/%s.\n' "$BRANCH" "$REMOTE" "$REMOTE_BRANCH"
