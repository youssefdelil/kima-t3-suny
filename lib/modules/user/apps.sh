#!/usr/bin/env bash
# lib/modules/user/apps.sh — App support cache cleanup

apps::clean() {
  if [[ "$TARGET_CACHES" != "true" ]]; then
    return 0
  fi

  log::section "Apps"
  local start
  start=$(date +%s)
  local total_size=0

  local app_caches=(
    "$HOME/Library/Application Support/Slack/Cache"
    "$HOME/Library/Application Support/Slack/logs"
    "$HOME/Library/Application Support/discord/Cache"
    "$HOME/Library/Application Support/discord/logs"
    "$HOME/Library/Application Support/Telegram Desktop/tdata/emoji"
    "$HOME/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack/Cache"
    "$HOME/Library/Application Support/zoom.us/logs"
    "$HOME/Library/Application Support/Figma/logs"
  )

  for cache in "${app_caches[@]}"; do
    if [[ -d "$cache" ]]; then
      local s
      s=$(utils::get_size_bytes "$cache")
      if (( s > 10240 )); then
        log::verbose "  App cache: $(basename "$(dirname "$cache")")/$(basename "$cache") — $(utils::format_bytes "$s")"
        total_size=$(( total_size + s ))
        utils::safe_rm "$cache" "app cache"
      fi
    fi
  done

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$total_size" -gt 0 ] && { [ "$DRY_RUN" == "true" ] && echo "pending" || echo "done"; } || echo "clean")"

  log::module_result "Apps" "$status" "$total_size" "$dur"
  module::register "Apps" "Caches & Logs" "$total_size" "$([ "$DRY_RUN" == "false" ] && echo "$total_size" || echo 0)" "$status" "$total_size" "$dur"
}
