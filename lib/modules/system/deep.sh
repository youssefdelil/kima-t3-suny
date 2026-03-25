#!/usr/bin/env bash
# lib/modules/system/deep.sh — Deep system cleanup: rotated logs, old diagnostics

system_deep::clean() {
  if [[ "$TARGET_SYSTEM_DEEP" != "true" ]]; then
    return 0
  fi

  log::section "System Deep"
  local start
  start=$(date +%s)
  local total_size=0

  # ── Rotated / compressed logs ──────────────────────────────────────────────
  log::verbose "Scanning for rotated log files..."
  local paths=(
    "/var/log"
    "$HOME/Library/Logs"
  )
  for log_dir in "${paths[@]}"; do
    while IFS= read -r -d '' f; do
      local s
      s=$(utils::get_size_bytes "$f")
      total_size=$(( total_size + s ))
      log::verbose "  Stale log: $f ($(utils::format_bytes "$s"))"
      utils::safe_rm "$f" "rotated log"
    done < <(find "$log_dir" -type f \( -name "*.gz" -o -name "*.bz2" -o -name "*.old" \) -mtime +30 -print0 2>/dev/null)
  done

  # ── MobileSync backups older than 90 days ─────────────────────────────────
  local mobile_sync="$HOME/Library/Application Support/MobileSync/Backup"
  if [[ -d "$mobile_sync" ]]; then
    while IFS= read -r -d '' backup; do
      local bs
      bs=$(utils::get_size_bytes "$backup")
      if (( bs > 0 )); then
        log::verbose "  Old iOS backup: $backup ($(utils::format_bytes "$bs"))"
        total_size=$(( total_size + bs ))
        utils::safe_rm "$backup" "iOS backup"
      fi
    done < <(find "$mobile_sync" -maxdepth 1 -mindepth 1 -type d -mtime +90 -print0 2>/dev/null)
  fi

  # ── com.apple diagnostics ─────────────────────────────────────────────────
  local diag_dir="$HOME/Library/Logs/CrashReporter"
  if [[ -d "$diag_dir" ]]; then
    local ds
    ds=$(utils::get_size_bytes "$diag_dir")
    if (( ds > 0 )); then
      log::verbose "  CrashReporter logs: $(utils::format_bytes "$ds")"
      total_size=$(( total_size + ds ))
      while IFS= read -r -d '' f; do
        utils::safe_rm "$f" "crash reporter log"
      done < <(find "$diag_dir" -type f -mtime +14 -print0 2>/dev/null)
    fi
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$total_size" -gt 0 ] && { [ "$DRY_RUN" == "true" ] && echo "pending" || echo "done"; } || echo "clean")"

  log::module_result "System Deep" "$status" "$total_size" "$dur"
  module::register "System Deep" "System" "$total_size" "$([ "$DRY_RUN" == "false" ] && echo "$total_size" || echo 0)" "$status" "$total_size" "$dur"
}
