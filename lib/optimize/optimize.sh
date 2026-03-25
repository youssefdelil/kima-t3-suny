#!/usr/bin/env bash
# lib/optimize/optimize.sh — System optimizations: DNS flush, LS rebuild, SQLite vacuum

optimize::run() {
  if [[ "${TARGET_OPTIMIZE:-false}" != "true" ]]; then
    return 0
  fi

  log::section "Optimize"
  local start
  start=$(date +%s)

  if [[ "$DRY_RUN" == "true" ]]; then
    log::info "[dry-run] Optimize would:"
    log::info "  • Flush DNS cache (dscacheutil -flushcache)"
    log::info "  • Rebuild LaunchServices database (lsregister)"
    log::info "  • Vacuum SQLite databases in ~/Library"
  else
    # DNS flush
    log::verbose "Flushing DNS cache..."
    dscacheutil -flushcache 2>/dev/null && \
      killall -HUP mDNSResponder 2>/dev/null || true
    log::success "DNS cache flushed"

    # LaunchServices rebuild
    log::verbose "Rebuilding LaunchServices database..."
    local lsregister
    lsregister=$(find /System/Library/Frameworks -name lsregister 2>/dev/null | head -1)
    if [[ -n "$lsregister" ]]; then
      "$lsregister" -kill -r -domain local -domain system -domain user >/dev/null 2>&1 || true
      log::success "LaunchServices database rebuilt"
    else
      log::verbose "lsregister not found — skipping"
    fi

    # SQLite vacuum
    log::verbose "Vacuuming SQLite databases..."
    local vacuum_count=0
    while IFS= read -r -d '' db; do
      sqlite3 "$db" "VACUUM;" 2>/dev/null && vacuum_count=$(( vacuum_count + 1 )) || true
    done < <(find "$HOME/Library" -name "*.db" -size +100k -maxdepth 5 -print0 2>/dev/null)
    log::success "Vacuumed $vacuum_count SQLite databases"
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$DRY_RUN" == "true" ] && echo "pending" || echo "done")"

  log::module_result "Optimize" "$status" "" "$dur"
  module::register "Optimize" "Optimization" 0 0 "$status" 0 "$dur"
}
