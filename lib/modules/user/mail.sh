#!/usr/bin/env bash
# lib/modules/user/mail.sh — Clean old Mail downloads and recent-item metadata

mail::clean() {
  if [[ "$TARGET_MAIL" != "true" ]]; then
    return 0
  fi

  log::section "Mail"
  local start
  start=$(date +%s)
  local total_size=0

  local mail_dirs=(
    "$HOME/Library/Mail/V10/MailData/Attachments"
    "$HOME/Library/Mail/V9/MailData/Attachments"
    "$HOME/Library/Mail/V8/MailData/Attachments"
    "$HOME/Library/Containers/com.apple.mail/Data/Library/Caches"
  )

  for mdir in "${mail_dirs[@]}"; do
    if [[ -d "$mdir" ]]; then
      local ms
      ms=$(utils::get_size_bytes "$mdir")
      if (( ms > 0 )); then
        log::verbose "  Mail attachments: $(utils::format_bytes "$ms")"
        total_size=$(( total_size + ms ))
        while IFS= read -r -d '' f; do
          utils::safe_rm "$f" "mail attachment"
        done < <(find "$mdir" -type f -mtime +30 -print0 2>/dev/null)
      fi
    fi
  done

  # ── Recent items metadata ──────────────────────────────────────────────────
  local recent="$HOME/Library/Application Support/com.apple.sharedfilelist"
  if [[ -d "$recent" ]]; then
    local rs
    rs=$(utils::get_size_bytes "$recent")
    if (( rs > 0 )); then
      log::verbose "  Recent items metadata: $(utils::format_bytes "$rs")"
      total_size=$(( total_size + rs ))
      while IFS= read -r -d '' f; do
        utils::safe_rm "$f" "recent-items metadata"
      done < <(find "$recent" -name "*.sfl*" -type f -mtime +90 -print0 2>/dev/null)
    fi
  fi

  local end
  end=$(date +%s)
  local dur=$(( end - start ))
  local status="$([ "$total_size" -gt 0 ] && { [ "$DRY_RUN" == "true" ] && echo "pending" || echo "done"; } || echo "clean")"

  log::module_result "Mail" "$status" "$total_size" "$dur"
  module::register "Mail" "Caches & Logs" "$total_size" "$([ "$DRY_RUN" == "false" ] && echo "$total_size" || echo 0)" "$status" "$total_size" "$dur"
}
