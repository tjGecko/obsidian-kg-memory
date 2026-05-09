#!/usr/bin/env bash
# uninstall-mac.sh — Remove the agent stack. Vault and Aqua Voice preserved by default.
# Pass --purge to also remove the vault.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

cat <<EOF

This will remove:
  • Claude Code (npm uninstall -g)
  • OpenAI Codex CLI (npm uninstall -g)
  • Hermes Agent (~/.hermes and ~/.local/bin/hermes)
  • Obsidian.app
  • kg-memory skills (~/.claude/skills/kg-memory)
  • KG state file (~/.claude/kg_state.json)

Will NOT remove:
  • Aqua Voice (you may want it for other apps)
  • Your KG vault at $KG_VAULT$([[ "$PURGE" == true ]] && echo " ← REMOVED because --purge was passed")
  • Homebrew, Node, Python (other tools may depend on them)
  • Your Anthropic / OpenAI account credentials

EOF

if ! confirm "Proceed?"; then
  log "Aborted."
  exit 0
fi

# ── npm globals ────────────────────────────────────────────────────────────
if have_cmd npm; then
  npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
  npm uninstall -g @openai/codex 2>/dev/null || true
fi

# ── Hermes ─────────────────────────────────────────────────────────────────
rm -f "$HOME/.local/bin/hermes" 2>/dev/null || true
rm -rf "$HERMES_DIR" 2>/dev/null || true

# ── Obsidian ───────────────────────────────────────────────────────────────
[[ -d "/Applications/Obsidian.app" ]] && rm -rf "/Applications/Obsidian.app"

# ── kg-memory skill + state ────────────────────────────────────────────────
rm -rf "$CLAUDE_SKILLS/kg-memory" 2>/dev/null || true
rm -f "$CLAUDE_DIR/kg_state.json" 2>/dev/null || true

# ── Vault (only with --purge) ──────────────────────────────────────────────
if [[ "$PURGE" == true ]]; then
  log_warn "Removing vault at $KG_VAULT"
  rm -rf "$KG_VAULT"
fi

log_ok "Uninstall complete."
