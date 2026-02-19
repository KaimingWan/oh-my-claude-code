#!/bin/bash
# distill.sh — Distillation engine: episodes → rules auto-promotion
# Sourced library. Caller must set: EPISODES_FILE, RULES_FILE, RULES_DIR, ARCHIVE_DIR

# ── distill_check ──
# Scan episodes for keywords with freq ≥2, not covered by rules.md or .claude/rules/.
# Determine severity, write rule, mark source episodes promoted.
distill_check() {
  [ -f "$EPISODES_FILE" ] || return 0

  local kw_counts
  kw_counts=$(grep '| active |' "$EPISODES_FILE" 2>/dev/null \
    | cut -d'|' -f3 | tr ',' '\n' | sed 's/^ *//;s/ *$//;s/\[correction\]//' | grep -v '^$' \
    | sort | uniq -c | sort -rn)
  [ -z "$kw_counts" ] && return 0

  local covered_rules_dir=""
  [ -d "$RULES_DIR" ] && covered_rules_dir=$(cat "$RULES_DIR"/*.md 2>/dev/null | tr '[:upper:]' '[:lower:]')
  local covered_sections=""
  [ -f "$RULES_FILE" ] && covered_sections=$(grep '^## \[' "$RULES_FILE" 2>/dev/null | tr '[:upper:]' '[:lower:]')

  local distilled=0
  while read -r count kw; do
    [ -z "$kw" ] && continue
    [ "$count" -lt 2 ] && continue
    local kw_lower
    kw_lower=$(echo "$kw" | tr '[:upper:]' '[:lower:]')

    # Skip if keyword already in rules.md section headers
    if echo "$covered_sections" | grep -qw "$kw_lower" 2>/dev/null; then
      continue
    fi

    # Keyword covered by .claude/rules/ → mark promoted, no rule written
    if echo "$covered_rules_dir" | grep -qw "$kw_lower" 2>/dev/null; then
      _mark_promoted "$kw"
      distilled=$((distilled + 1))
      continue
    fi

    # Extract newest active episode with this keyword
    local newest_line
    newest_line=$(grep '| active |' "$EPISODES_FILE" | grep -w "$kw" | tail -1)
    [ -z "$newest_line" ] && continue

    local summary
    summary=$(echo "$newest_line" | cut -d'|' -f4 | sed 's/^ *//;s/ *$//')

    # Severity: check ALL episodes with this keyword for action words or [correction]
    local severity="🟡"
    local all_lines
    all_lines=$(grep '| active |' "$EPISODES_FILE" | grep -w "$kw")
    if echo "$all_lines" | grep -qiE '禁止|必须|never|always|CRITICAL|blocked|拦截'; then
      severity="🔴"
    fi
    if echo "$all_lines" | cut -d'|' -f3 | grep -q '\[correction\]'; then
      severity="🔴"
    fi

    local kw_field
    kw_field=$(echo "$newest_line" | cut -d'|' -f3)

    local section_kws
    section_kws=$(echo "$kw_field" | sed 's/\[correction\]//g' | tr -d ' ')

    _write_rule "$section_kws" "$severity" "$summary"
    _mark_promoted "$kw"
    distilled=$((distilled + 1))
  done <<< "$kw_counts"

  [ "$distilled" -gt 0 ] && echo "⚗️ Distilled $distilled keyword groups into rules"
}

# ── archive_promoted ──
# Move promoted/resolved episodes to monthly archive file.
archive_promoted() {
  [ -f "$EPISODES_FILE" ] || return 0
  mkdir -p "$ARCHIVE_DIR"

  local to_archive
  to_archive=$(grep -E '\| (promoted|resolved) \|' "$EPISODES_FILE" 2>/dev/null)
  [ -z "$to_archive" ] && return 0

  local archive_file="$ARCHIVE_DIR/episodes-$(date +%Y-%m).md"
  echo "$to_archive" >> "$archive_file"

  grep -vE '\| (promoted|resolved) \|' "$EPISODES_FILE" > /tmp/distill-ep-$$.tmp \
    && mv /tmp/distill-ep-$$.tmp "$EPISODES_FILE"

  local count
  count=$(echo "$to_archive" | wc -l | tr -d ' ')
  echo "📦 Archived $count episodes → $archive_file"
}

# ── section_cap_enforce ──
# For each section in rules.md with >5 rules, remove oldest (lowest numbered) until ≤5.
section_cap_enforce() {
  [ -f "$RULES_FILE" ] || return 0
  local tmpfile="/tmp/distill-cap-$$.tmp"
  awk '
    /^## \[/ {
      if (section) flush()
      header = $0; section = 1; count = 0; delete rules; next
    }
    section && /^[0-9]/ { count++; rules[count] = $0; next }
    !section { print; next }
    END { if (section) flush() }
    function flush() {
      print header
      if (count > 5) {
        for (i = count - 4; i <= count; i++) print rules[i]
      } else {
        for (i = 1; i <= count; i++) print rules[i]
      }
    }
  ' "$RULES_FILE" > "$tmpfile" && mv "$tmpfile" "$RULES_FILE"
}

# ── Internal helpers ──

_mark_promoted() {
  local kw="$1"
  local tmpfile="/tmp/distill-mark-$$.tmp"
  awk -v kw="$kw" '
    /\| active \|/ && index($0, kw) { sub(/\| active \|/, "| promoted |") }
    { print }
  ' "$EPISODES_FILE" > "$tmpfile" && mv "$tmpfile" "$EPISODES_FILE"
}

_write_rule() {
  local section_kws="$1" severity="$2" summary="$3"
  local header="## [$section_kws]"

  if [ ! -s "$RULES_FILE" ]; then
    printf '# Agent Rules — Staging Area\n\n%s\n%s 1. %s\n' "$header" "$severity" "$summary" > "$RULES_FILE"
    return
  fi

  if grep -qF "$header" "$RULES_FILE" 2>/dev/null; then
    local max_num
    max_num=$(awk -v hdr="$header" '
      $0 == hdr { found=1; next }
      found && /^## \[/ { exit }
      found && /^[0-9]/ { n = $0+0; if (n>max) max=n }
      END { print max+0 }
    ' "$RULES_FILE")
    local new_num=$((max_num + 1))
    local tmpfile="/tmp/distill-wr-$$.tmp"
    awk -v hdr="$header" -v rule="'"$severity"' '"$new_num"'. '"$summary"'" '
      $0 == hdr { print; found=1; next }
      found && (/^## \[/ || /^$/) && !added { print rule; added=1 }
      { print }
      END { if (found && !added) print rule }
    ' "$RULES_FILE" > "$tmpfile" && mv "$tmpfile" "$RULES_FILE"
  else
    printf '\n%s\n%s 1. %s\n' "$header" "$severity" "$summary" >> "$RULES_FILE"
  fi
}
