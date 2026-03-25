#!/usr/bin/env bash
# lib/modules/system/brew.sh — Homebrew cleanup and autoremove

brew::clean() {
  if [[ "$TARGET_BREW" != "true" ]]; then
    return 0
  fi

  log::section "Homebrew"

  if ! command -v brew >/dev/null 2>&1; then
    log::module_result "Homebrew" "skipped" "" ""
    module::register "Homebrew" "Caches & Logs" 0 0 "skipped" 0 0
    return 0
  fi

  local start
  start=$(date +%s)
  local free_before
  free_before=$(utils::get_free_bytes)

  if [[ "$DRY_RUN" == "true" ]]; then
    log::verbose "$(brew cleanup --dry-run 2>/dev/null | head -20)"
    log::info "[dry-run] brew cleanup --prune=all --dry-run"
    local freed_est
    freed_est=$(brew cleanup --dry-run 2>/dev/null | grep -oE '[0-9.]+ [KMG]B' | tail -1 || echo "0 B")
    log::verbose "Estimated reclaimable: $freed_est"
  else
    log::verbose "Running brew cleanup..."
    brew cleanup --prune=all -q 2>/dev/null || true
    log::verbose "Running brew autoremove..."
    brew autoremove -q 2>/dev/null || true
  fi

  local free_after
  free_after=$(utils::get_free_bytes)
  local freed=$(( free_after - free_before ))
  [[ $freed -lt 0 ]] && freed=0

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$DRY_RUN" == "true" ] && echo "pending" || echo "done")"

  log::module_result "Homebrew" "$status" "$freed" "$dur"
  module::register "Homebrew" "Caches & Logs" "$freed" "$freed" "$status" "$freed" "$dur"
}
