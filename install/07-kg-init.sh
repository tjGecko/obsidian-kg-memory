#!/usr/bin/env bash
# 07-kg-init.sh — Copy the kg-memory skill set into ~/.claude/skills/
# and seed the vault structure.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

# ── Copy skills into Claude Code's skills dir ──────────────────────────────
ensure_dir "$CLAUDE_SKILLS"
SKILL_SRC="$SKILLS_DIR/kg-memory"
SKILL_DST="$CLAUDE_SKILLS/kg-memory"

if [[ ! -d "$SKILL_SRC" ]]; then
  log_err "Source skill dir not found: $SKILL_SRC"
  exit 1
fi

if [[ -d "$SKILL_DST" ]]; then
  log "Updating skills at $SKILL_DST"
  rsync -a --delete "$SKILL_SRC/" "$SKILL_DST/"
else
  log "Installing skills to $SKILL_DST"
  cp -R "$SKILL_SRC" "$SKILL_DST"
fi
log_ok "Skills installed at $SKILL_DST"

# ── Seed the vault structure ──────────────────────────────────────────────
ensure_dir "$KG_VAULT/kg/notes"
ensure_dir "$KG_VAULT/kg/sources"
ensure_dir "$KG_VAULT/kg/topics"

TODAY=$(date +%Y-%m-%d)

substitute_dates() {
  # in-place substitution of {{created}} and {{updated}}
  local f="$1"
  sed -i.bak \
    -e "s/{{created}}/$TODAY/g" \
    -e "s/{{updated}}/$TODAY/g" \
    "$f" && rm -f "$f.bak"
}

write_if_missing() {
  local template="$1"
  local target="$2"
  if [[ -f "$target" ]]; then
    log_skip "$target already exists"
  else
    cp "$template" "$target"
    substitute_dates "$target"
    log_ok "Wrote $target"
  fi
}

TEMPLATES="$SKILL_SRC/templates"
write_if_missing "$TEMPLATES/_index.md"     "$KG_VAULT/kg/_index.md"
write_if_missing "$TEMPLATES/_timeline.md"  "$KG_VAULT/kg/_timeline.md"
write_if_missing "$TEMPLATES/_dashboard.md" "$KG_VAULT/kg/_dashboard.md"

# ── State file ─────────────────────────────────────────────────────────────
STATE="$CLAUDE_DIR/kg_state.json"
if [[ -f "$STATE" ]]; then
  log_skip "$STATE already exists"
else
  cat > "$STATE" <<EOF
{
  "schema_version": 1,
  "vault_path": "$KG_VAULT",
  "last_full_update": null,
  "cards": {},
  "stats": {
    "notes": 0,
    "sources": 0,
    "topics": 0,
    "total_pages": 3
  }
}
EOF
  log_ok "Initialized state at $STATE"
fi

cat <<EOF

  KG vault ready at: $KG_VAULT/kg/
  Skills installed at: $SKILL_DST

  In a Claude Code session, try:
    /kg-add-note "this is my first captured thought"

EOF
