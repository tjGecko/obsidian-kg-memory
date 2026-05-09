#!/usr/bin/env bash
# install-mac.sh — Orchestrate the full agent stack install on macOS.
# Idempotent: re-run any time. Each numbered step is also runnable standalone.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_macos

cat <<EOF

╔══════════════════════════════════════════════════════════════════╗
║   Obsidian KG Memory + Mac Agent Stack — Installer               ║
╠══════════════════════════════════════════════════════════════════╣
║   Will install / verify:                                         ║
║     1. Homebrew, Node 20, Python 3.11, git, jq                   ║
║     2. Claude Code CLI                                           ║
║     3. OpenAI Codex CLI                                          ║
║     4. Hermes Agent (NousResearch)                               ║
║     5. Aqua Voice                                                ║
║     6. Obsidian + Dataview plugin                                ║
║     7. KG vault init + skills install                            ║
║     8. Verification                                              ║
║                                                                  ║
║   Vault location: $KG_VAULT
║                                                                  ║
║   Idempotent — safe to re-run.                                   ║
╚══════════════════════════════════════════════════════════════════╝

EOF

if ! confirm "Proceed?"; then
  log "Aborted by user."
  exit 0
fi

steps=(
  "01-prereqs.sh"
  "02-claude-code.sh"
  "03-codex.sh"
  "04-hermes.sh"
  "05-aqua-voice.sh"
  "06-obsidian.sh"
  "07-kg-init.sh"
  "08-verify.sh"
)

for step in "${steps[@]}"; do
  echo
  log "Step: $step"
  if [[ ! -x "$SCRIPT_DIR/$step" ]]; then
    chmod +x "$SCRIPT_DIR/$step"
  fi
  if ! "$SCRIPT_DIR/$step"; then
    log_err "Step $step failed."
    log "You can re-run individual steps once the issue is fixed:"
    log "  $SCRIPT_DIR/$step"
    exit 1
  fi
done

echo
log_ok "All steps complete."
cat <<EOF

Next steps:
  • Open Obsidian → it will prompt you to open a vault → choose:
      $KG_VAULT
  • Run \`claude\` in any directory and try:
      /kg-add-note "this is my first captured thought"
  • If you haven't yet, set up your OpenAI API key in:
      $HERMES_DIR/.env

See docs/MOM-CHEATSHEET.md for daily-use guidance.

EOF
