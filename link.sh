#!/bin/bash
# macOS Bash 3.2 compatible. Preview first; only --apply modifies targets.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd -P)"
TARGET_HOME="$HOME"
APPLY=false
SELECTED=()

usage() {
  cat <<'HELP'
Usage: ./link.sh [--apply | --dry-run] [--home ABSOLUTE_PATH] [APPLICATION ...]

Applications: ghostty vscode zed nvim vim claude-code (neovim is an alias for nvim)
Without a selection, all applications are included. Preview is the default.
--apply backs up existing targets before creating links. No extensions are installed.
HELP
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --apply) APPLY=true ;;
    --dry-run) APPLY=false ;;
    --home)
      [ "$#" -ge 2 ] || fail '--home requires an absolute path'
      TARGET_HOME="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    ghostty|vscode|zed|nvim|vim|claude-code) SELECTED+=("$1") ;;
    neovim) SELECTED+=("nvim") ;;
    *) fail "Unknown application or option: $1" ;;
  esac
  shift
done

while [ "$TARGET_HOME" != / ] && [ "${TARGET_HOME%/}" != "$TARGET_HOME" ]; do
  TARGET_HOME="${TARGET_HOME%/}"
done
case "$TARGET_HOME" in
  /|*/..|*/../*|*/.|*/./*) fail 'Target home cannot be the filesystem root or contain dot segments' ;;
  /*) ;;
  *) fail '--home must be an absolute path' ;;
esac

selected() {
  [ "${#SELECTED[@]}" -eq 0 ] && return 0
  local item
  for item in "${SELECTED[@]}"; do
    [ "$item" = "$1" ] && return 0
  done
  return 1
}

safe_relative() {
  case "$1" in
    ''|/*|.|..|./*|../*|*/./*|*/../*|*/.|*/..) return 1 ;;
    *) return 0 ;;
  esac
}

physical_parent() {
  local path="$1" suffix=''
  while [ ! -d "$path" ]; do
    suffix="/$(basename "$path")$suffix"
    path="$(dirname "$path")"
  done
  printf '%s%s\n' "$(cd "$path" && pwd -P)" "$suffix"
}

already_linked() {
  local target="$1" source="$2"
  [ "$target" -ef "$source" ] || return 1
  [ -L "$target" ] && return 0
  # A directory symlink may expose the source itself. A separate hardlink is
  # not sufficient: a Git update can replace the source inode.
  [ "$(physical_parent "$(dirname "$target")")/$(basename "$target")" = "$source" ]
}

SOURCES=()
TARGETS=()
# Validate every selected entry before any filesystem mutation.
while IFS=$'\t' read -r application source relative extra || [ -n "$application" ]; do
  case "$application" in ''|\#*) continue ;; esac
  selected "$application" || continue
  [ -n "$source" ] && [ -n "$relative" ] && [ -z "$extra" ] || fail 'Invalid links.tsv entry'
  safe_relative "$source" && safe_relative "$relative" || fail 'Mapping paths must stay inside the repository and target home'
  [ -e "$REPO_DIR/$source" ] || fail "Missing source: $source"
  target="$TARGET_HOME/$relative"
  parent="$(dirname "$target")"
  while [ "$parent" != / ]; do
    if { [ -e "$parent" ] || [ -L "$parent" ]; } && [ ! -d "$parent" ]; then
      fail "Target parent is not a directory: $parent"
    fi
    parent="$(dirname "$parent")"
  done
  # A parent directory may already be a symlink into this checkout. Never move
  # a source through such an alias, or replace it with a link pointing to itself.
  if ! already_linked "$target" "$REPO_DIR/$source"; then
    physical_target="$(physical_parent "$(dirname "$target")")/$(basename "$target")"
    case "$physical_target/" in
      "$REPO_DIR/"*) fail "Target would modify the repository: $target" ;;
    esac
    case "$REPO_DIR/" in
      "$physical_target/"*) fail "Target would move the repository: $target" ;;
    esac
  fi
  SOURCES+=("$REPO_DIR/$source")
  TARGETS+=("$target")
done < "$REPO_DIR/links.tsv"
[ "${#SOURCES[@]}" -gt 0 ] || fail 'No matching configuration sources'

BACKUP_SESSION=''
for ((index=0; index<${#SOURCES[@]}; index++)); do
  source="${SOURCES[$index]}"
  target="${TARGETS[$index]}"
  if already_linked "$target" "$source"; then
    printf '[skip] %s\n' "$target"
    continue
  fi
  if [ "$APPLY" = false ]; then
    printf '[preview] %s -> %s\n' "$target" "$source"
    continue
  fi

  mkdir -p "$(dirname "$target")"
  backup=''
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ -z "$BACKUP_SESSION" ]; then
      backup_root="$TARGET_HOME/.local/state/blue-dotfiles/backups"
      mkdir -p "$backup_root"
      BACKUP_SESSION="$(mktemp -d "$backup_root/$(date +%Y%m%d-%H%M%S).XXXXXX")"
    fi
    backup="$BACKUP_SESSION/${target#"$TARGET_HOME/"}"
    mkdir -p "$(dirname "$backup")"
    mv "$target" "$backup"
    printf '[backup] %s -> %s\n' "$target" "$backup"
  fi
  if ! ln -s "$source" "$target"; then
    if [ -n "$backup" ] && [ ! -e "$target" ] && [ ! -L "$target" ]; then
      mv "$backup" "$target"
    fi
    fail "Could not link $target; inspect the backup before retrying"
  fi
  printf '[linked] %s -> %s\n' "$target" "$source"
done

if [ "$APPLY" = false ]; then
  printf '\nPreview only. Add --apply to back up and link these targets.\n'
fi
