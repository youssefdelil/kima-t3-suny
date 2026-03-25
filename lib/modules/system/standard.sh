#!/usr/bin/env bash
# lib/modules/system/standard.sh — System cleanup: crash reports, DS_Store, Trash, dev caches

system::clean() {
  if [[ "$TARGET_SYSTEM" != "true" ]]; then
    return 0
  fi

  log::section "System"
  local start
  start=$(date +%s)

  local total_size=0
  local found=0

  # ── Trash ──────────────────────────────────────────────────────────────────
  local trash_path="$HOME/.Trash"
  if [[ -d "$trash_path" ]]; then
    local trash_size
    trash_size=$(utils::get_size_bytes "$trash_path")
    log::verbose "Trash: $(utils::format_bytes "$trash_size")"
    if (( trash_size > 0 )); then
      found=$(( found + 1 ))
      total_size=$(( total_size + trash_size ))
      utils::safe_rm "$trash_path" "Trash"
    fi
  fi

  # ── .DS_Store files ────────────────────────────────────────────────────────
  log::verbose "Scanning for .DS_Store files..."
  local ds_count=0
  local ds_size=0
  while IFS= read -r -d '' f; do
    local s
    s=$(utils::get_size_bytes "$f")
    ds_size=$(( ds_size + s ))
    ds_count=$(( ds_count + 1 ))
    utils::safe_rm "$f" ".DS_Store"
  done < <(find "$HOME" -name ".DS_Store" -maxdepth 8 -print0 2>/dev/null)

  if (( ds_count > 0 )); then
    log::verbose "Found $ds_count .DS_Store files ($(utils::format_bytes "$ds_size"))"
    total_size=$(( total_size + ds_size ))
    found=$(( found + 1 ))
  fi

  # ── Crash reports ──────────────────────────────────────────────────────────
  for crash_dir in \
    "$HOME/Library/Logs/DiagnosticReports" \
    "/Library/Logs/DiagnosticReports"; do
    if [[ -d "$crash_dir" ]]; then
      local csize
      csize=$(utils::get_size_bytes "$crash_dir")
      if (( csize > 0 )); then
        log::verbose "Crash reports: $(utils::format_bytes "$csize") in $crash_dir"
        total_size=$(( total_size + csize ))
        found=$(( found + 1 ))
        while IFS= read -r -d '' f; do
          utils::safe_rm "$f" "crash report"
        done < <(find "$crash_dir" -type f \( -name "*.crash" -o -name "*.ips" -o -name "*.diag" \) -print0 2>/dev/null)
      fi
    fi
  done

  # ── Developer caches under ~/Library/Developer ─────────────────────────────
  local dev_cache="$HOME/Library/Developer/Xcode/UserData/IB Support"
  if [[ -d "$dev_cache" ]]; then
    local dc_size
    dc_size=$(utils::get_size_bytes "$dev_cache")
    if (( dc_size > 0 )); then
      log::verbose "IB Support cache: $(utils::format_bytes "$dc_size")"
      total_size=$(( total_size + dc_size ))
      found=$(( found + 1 ))
      utils::safe_rm "$dev_cache" "Xcode IB Support"
    fi
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))

  local status="clean"
  if (( total_size > 0 )); then
    status="$([ "$DRY_RUN" == "true" ] && echo "pending" || echo "done")"
  fi

  log::module_result "System" "$status" "$total_size" "$dur"
  module::register "System" "System" "$total_size" "$([ "$DRY_RUN" == "false" ] && echo "$total_size" || echo 0)" "$status" "$total_size" "$dur"
}
