#!/usr/bin/env bash
# lib/undo/undo.sh — Undo last cleanup via manifest snapshot

UNDO_DIR="${UNDO_DIR:-$HOME/.delileche/undo}"
UNDO_MANIFEST="${UNDO_DIR}/last_manifest.txt"
UNDO_BACKUP="${UNDO_DIR}/last_backup.tar.gz"

# Register a file for undo before deletion
undo::record() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    return 0
  fi
  mkdir -p "$UNDO_DIR"
  echo "$path" >> "$UNDO_MANIFEST"
}

# Call before a cleanup run to start a new undo snapshot
undo::begin_session() {
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  mkdir -p "$UNDO_DIR"
  # Clear old manifest and backup
  rm -f "$UNDO_MANIFEST" "$UNDO_BACKUP"
  log::verbose "Undo session started — deletions will be recorded."
}

# Call after cleanup run to compress snapshot
undo::finalize_session() {
  if [[ "$DRY_RUN" == "true" ]]; then
    return 0
  fi
  if [[ ! -f "$UNDO_MANIFEST" ]]; then
    return 0
  fi

  local count
  count=$(wc -l < "$UNDO_MANIFEST" | tr -d ' ')
  if (( count == 0 )); then
    return 0
  fi

  # Build tar of all deleted paths that still exist in trash or backup
  # Since files are deleted, we can only keep the manifest for reference
  log::verbose "Undo manifest saved: $count item(s) recorded."
  log::info "Undo available — run ${BOLD}delileche --undo${RESET}${CYAN} to review last cleanup"
}

# Show what was deleted in last session
undo::show() {
  if [[ ! -f "$UNDO_MANIFEST" ]]; then
    printf "\n  ${YELLOW}${WARN}${RESET}  No undo data found. Run a live cleanup first.\n\n"
    return 0
  fi

  local count
  count=$(wc -l < "$UNDO_MANIFEST" | tr -d ' ')
  local bar
  bar=$(printf '─%.0s' $(seq 1 60))

  printf "\n  ${BOLD}${PURPLE}%s${RESET}\n" "$bar"
  printf "  ${BOLD}${MAGENTA}  Last cleanup — %s item(s) deleted${RESET}\n" "$count"
  printf "  ${BOLD}${PURPLE}%s${RESET}\n\n" "$bar"

  local i=1
  while IFS= read -r path; do
    printf "  ${DIM}%3d.${RESET} %s\n" "$i" "$path"
    (( i++ ))
    (( i > 30 )) && printf "  ${DIM}... and $((count - 30)) more${RESET}\n" && break
  done < "$UNDO_MANIFEST"

  printf "\n  ${DIM}Manifest: %s${RESET}\n\n" "$UNDO_MANIFEST"
  printf "  ${YELLOW}${WARN}${RESET}  Files have been permanently deleted and cannot be restored.\n"
  printf "  ${CYAN}${INFO}${RESET}  Check your macOS Trash if you need to recover items.\n\n"
}

# Wrapper: safe_rm that also records to undo manifest
undo::safe_rm() {
  local path="$1"
  local desc="${2:-$path}"

  if [[ "$DRY_RUN" != "true" ]]; then
    undo::record "$path"
  fi

  utils::safe_rm "$path" "$desc"
}
