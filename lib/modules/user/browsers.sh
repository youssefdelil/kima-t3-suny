#!/usr/bin/env bash
# lib/modules/user/browsers.sh — Browser cache cleanup: Chrome, Firefox, Safari, Arc, Brave

browsers::clean() {
  if [[ "$TARGET_CACHES" != "true" ]]; then
    return 0
  fi

  log::section "Browsers"
  local start
  start=$(date +%s)
  local total_size=0

  local browser_caches=(
    # Chrome
    "$HOME/Library/Caches/Google/Chrome/Default/Cache"
    "$HOME/Library/Application Support/Google/Chrome/Default/Code Cache"
    "$HOME/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage"
    # Firefox
    "$HOME/Library/Caches/Firefox/Profiles"
    # Safari
    "$HOME/Library/Caches/com.apple.Safari"
    "$HOME/Library/Safari/LocalStorage"
    # Arc browser (newer)
    "$HOME/Library/Caches/Company/Arc"
    "$HOME/Library/Application Support/Arc/User Data/Default/Cache"
    "$HOME/Library/Application Support/Arc/User Data/Default/Code Cache"
    # Brave
    "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cache"
    "$HOME/Library/Caches/BraveSoftware/Brave-Browser"
    # Edge
    "$HOME/Library/Caches/com.microsoft.edgemac"
    # Opera
    "$HOME/Library/Caches/com.operasoftware.Opera"
  )

  for cache in "${browser_caches[@]}"; do
    if [[ -d "$cache" ]]; then
      local s
      s=$(utils::get_size_bytes "$cache")
      if (( s > 10240 )); then
        log::verbose "  Browser cache: $(basename "$cache") — $(utils::format_bytes "$s")"
        total_size=$(( total_size + s ))
        utils::safe_rm "$cache" "browser cache: $(basename "$cache")"
      fi
    fi
  done

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$total_size" -gt 0 ] && { [ "$DRY_RUN" == "true" ] && echo "pending" || echo "done"; } || echo "clean")"

  log::module_result "Browsers" "$status" "$total_size" "$dur"
  module::register "Browsers" "Caches & Logs" "$total_size" "$([ "$DRY_RUN" == "false" ] && echo "$total_size" || echo 0)" "$status" "$total_size" "$dur"
}
