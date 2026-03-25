#!/usr/bin/env bash
# lib/modules/user/standard.sh — User caches: Zsh, Spotify, JetBrains, CocoaPods, pip

caches::clean() {
  if [[ "$TARGET_CACHES" != "true" ]]; then
    return 0
  fi

  log::section "Caches"
  local start
  start=$(date +%s)
  local total_size=0

  local cache_dirs=(
    "$HOME/Library/Caches/com.spotify.client"
    "$HOME/Library/Caches/JetBrains"
    "$HOME/Library/Caches/Google"
    "$HOME/Library/Caches/com.microsoft.VSCode"
    "$HOME/Library/Application Support/Code/logs"
    "$HOME/Library/Application Support/Code/CachedData"
    "$HOME/.gradle/caches"
    "$HOME/.m2/repository"
    "$HOME/.npm/_npx"
    "$HOME/.cache/pip"
    "$HOME/.cache/yarn"
    "$HOME/.cocoapods/repos"
    "$HOME/Library/Caches/CocoaPods"
  )

  for cache in "${cache_dirs[@]}"; do
    if [[ -d "$cache" ]]; then
      local s
      s=$(utils::get_size_bytes "$cache")
      if (( s > 10240 )); then  # > 10 KB
        log::verbose "  Cache: $(basename "$cache") — $(utils::format_bytes "$s")"
        total_size=$(( total_size + s ))
        utils::safe_rm "$cache" "cache: $(basename "$cache")"
      fi
    fi
  done

  # ── Zsh history leftovers ──────────────────────────────────────────────────
  local zsh_hist_dir="$HOME/.zsh_sessions"
  if [[ -d "$zsh_hist_dir" ]]; then
    local zs
    zs=$(utils::get_size_bytes "$zsh_hist_dir")
    if (( zs > 0 )); then
      log::verbose "  Zsh sessions: $(utils::format_bytes "$zs")"
      total_size=$(( total_size + zs ))
      while IFS= read -r -d '' f; do
        utils::safe_rm "$f" "zsh session"
      done < <(find "$zsh_hist_dir" -type f -mtime +7 -print0 2>/dev/null)
    fi
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$total_size" -gt 0 ] && { [ "$DRY_RUN" == "true" ] && echo "pending" || echo "done"; } || echo "clean")"

  log::module_result "Caches" "$status" "$total_size" "$dur"
  module::register "Caches" "Caches & Logs" "$total_size" "$([ "$DRY_RUN" == "false" ] && echo "$total_size" || echo 0)" "$status" "$total_size" "$dur"
}
