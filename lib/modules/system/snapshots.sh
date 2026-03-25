#!/usr/bin/env bash
# lib/modules/system/snapshots.sh — Delete local Time Machine snapshots

snapshots::clean() {
  if [[ "$TARGET_SNAPSHOTS" != "true" ]]; then
    return 0
  fi

  log::section "Snapshots"

  if ! command -v tmutil >/dev/null 2>&1; then
    log::module_result "Snapshots" "skipped" "" ""
    module::register "Snapshots" "Storage Management" 0 0 "skipped" 0 0
    return 0
  fi

  local start
  start=$(date +%s)
  local total_size=0
  local count=0

  # List local snapshots
  local snapshots
  snapshots=$(tmutil listlocalsnapshots / 2>/dev/null | grep "com.apple.TimeMachine" || true)

  if [[ -z "$snapshots" ]]; then
    log::verbose "No local Time Machine snapshots found."
    log::module_result "Snapshots" "clean" "" ""
    module::register "Snapshots" "Storage Management" 0 0 "clean" 0 0
    return 0
  fi

  local snapshot_count
  snapshot_count=$(echo "$snapshots" | wc -l | tr -d ' ')
  log::verbose "Found $snapshot_count local snapshot(s)"

  if [[ "$DRY_RUN" == "true" ]]; then
    log::info "[dry-run] Would delete $snapshot_count local Time Machine snapshot(s)"
    echo "$snapshots" | while IFS= read -r snap; do
      log::verbose "  $snap"
    done
  else
    while IFS= read -r snap; do
      local date_part
      date_part=$(echo "$snap" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)
      log::verbose "  Deleting snapshot: $snap"
      tmutil deletelocalsnapshots "$date_part" 2>/dev/null || true
      count=$(( count + 1 ))
    done <<< "$snapshots"
    log::success "Deleted $count snapshot(s)"
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$DRY_RUN" == "true" ] && echo "pending" || echo "done")"

  log::module_result "Snapshots" "$status" "" "$dur"
  module::register "Snapshots" "Storage Management" 0 0 "$status" 0 "$dur"
}
