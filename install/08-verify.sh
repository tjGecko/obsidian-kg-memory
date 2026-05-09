#!/usr/bin/env bash
# 08-verify.sh — Sanity check the install. Read-only.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

ok=0; fail=0
check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    log_ok "$label"
    ((ok+=1))
  else
    log_err "$label"
    ((fail+=1))
  fi
}

echo
log "Verification"

check "claude on PATH"          "have_cmd claude"
check "codex on PATH"           "have_cmd codex"
check "hermes on PATH"          "have_cmd hermes"
check "Obsidian.app present"    "[[ -d '/Applications/Obsidian.app' ]]"
check "Aqua Voice.app present"  "[[ -d '/Applications/Aqua Voice.app' ]]"
check "KG vault exists"         "[[ -d '$KG_VAULT/kg' ]]"
check "KG _index.md exists"     "[[ -f '$KG_VAULT/kg/_index.md' ]]"
check "Dataview plugin installed" "[[ -f '$KG_VAULT/.obsidian/plugins/dataview/main.js' ]]"
check "kg-memory skills installed" "[[ -f '$CLAUDE_SKILLS/kg-memory/SKILL.md' ]]"
check "kg state file present"   "[[ -f '$CLAUDE_DIR/kg_state.json' ]]"
check "Hermes config present"   "[[ -f '$HERMES_DIR/config.yaml' ]]"
check "Hermes .env present"     "[[ -f '$HERMES_DIR/.env' ]]"

echo
if [[ $fail -eq 0 ]]; then
  log_ok "All $ok checks passed."
else
  log_warn "$ok passed, $fail failed."
  log "Re-run the failing step's script (e.g., ./install/04-hermes.sh) to fix."
  exit 1
fi
