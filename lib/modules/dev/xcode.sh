#!/usr/bin/env bash
# lib/modules/dev/xcode.sh — Xcode DerivedData, Archives, DeviceSupport cleanup

xcode::clean() {
  if [[ "$TARGET_XCODE" != "true" ]]; then
    return 0
  fi

  log::section "Xcode"

  if ! command -v xcodebuild >/dev/null 2>&1 && [[ ! -d "$HOME/Library/Developer/Xcode" ]]; then
    log::module_result "Xcode" "skipped" "" ""
    module::register "Xcode" "Developer Tools" 0 0 "skipped" 0 0
    return 0
  fi

  local start
  start=$(date +%s)
  local total_size=0

  # ── DerivedData ────────────────────────────────────────────────────────────
  local derived_data="$HOME/Library/Developer/Xcode/DerivedData"
  if [[ -d "$derived_data" ]]; then
    local dd_size
    dd_size=$(utils::get_size_bytes "$derived_data")
    if (( dd_size > 0 )); then
      log::verbose "  DerivedData: $(utils::format_bytes "$dd_size")"
      total_size=$(( total_size + dd_size ))
      utils::safe_rm "$derived_data" "Xcode DerivedData"
    fi
  fi

  # ── Archives ──────────────────────────────────────────────────────────────
  local archives="$HOME/Library/Developer/Xcode/Archives"
  if [[ -d "$archives" ]]; then
    local ar_size
    ar_size=$(utils::get_size_bytes "$archives")
    if (( ar_size > 0 )); then
      log::verbose "  Archives: $(utils::format_bytes "$ar_size")"
      total_size=$(( total_size + ar_size ))
      # Only old archives (60+ days)
      while IFS= read -r -d '' ar; do
        local s
        s=$(utils::get_size_bytes "$ar")
        total_size=$(( total_size + s ))
        utils::safe_rm "$ar" "Xcode archive"
      done < <(find "$archives" -maxdepth 2 -name "*.xcarchive" -mtime +60 -print0 2>/dev/null)
    fi
  fi

  # ── iOS DeviceSupport ─────────────────────────────────────────────────────
  local device_support="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  if [[ -d "$device_support" ]]; then
    local ds_size
    ds_size=$(utils::get_size_bytes "$device_support")
    if (( ds_size > 0 )); then
      log::verbose "  iOS DeviceSupport: $(utils::format_bytes "$ds_size")"
      total_size=$(( total_size + ds_size ))
      # Remove device support for iOS versions older than 2 years
      while IFS= read -r -d '' dsdir; do
        local s
        s=$(utils::get_size_bytes "$dsdir")
        utils::safe_rm "$dsdir" "iOS DeviceSupport: $(basename "$dsdir")"
        log::verbose "    $(basename "$dsdir") ($(utils::format_bytes "$s"))"
      done < <(find "$device_support" -maxdepth 1 -mindepth 1 -type d -mtime +730 -print0 2>/dev/null)
    fi
  fi

  # ── Simulator caches ──────────────────────────────────────────────────────
  local sim_cache="$HOME/Library/Developer/CoreSimulator/Caches"
  if [[ -d "$sim_cache" ]]; then
    local sc_size
    sc_size=$(utils::get_size_bytes "$sim_cache")
    if (( sc_size > 0 )); then
      log::verbose "  Simulator caches: $(utils::format_bytes "$sc_size")"
      total_size=$(( total_size + sc_size ))
      utils::safe_rm "$sim_cache" "Simulator caches"
    fi
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$total_size" -gt 0 ] && { [ "$DRY_RUN" == "true" ] && echo "pending" || echo "done"; } || echo "clean")"

  log::module_result "Xcode" "$status" "$total_size" "$dur"
  module::register "Xcode" "Developer Tools" "$total_size" "$([ "$DRY_RUN" == "false" ] && echo "$total_size" || echo 0)" "$status" "$total_size" "$dur"
}
