#!/usr/bin/env bash
# install-mac.sh — Orchestrate the full agent stack install on macOS.
# Idempotent: re-run any time. Each numbered step is also runnable standalone.
#
# Agent-friendly modes:
#   OBSIDIAN_KG_NONINTERACTIVE=1   skip all confirm prompts
#   OBSIDIAN_KG_SKIP_TCC=1         skip the manual permissions phase
#   OBSIDIAN_KG_PIN_VERSIONS=1     install pinned versions from versions.env
#
# Final output: prints one summary JSON to stdout after all steps.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

require_macos

# Make Homebrew non-interactive everywhere.
export NONINTERACTIVE=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1
export HOMEBREW_NO_INSTALL_CLEANUP=1

ORCHESTRATOR_START=$(date +%s)

cat <<EOF

╔══════════════════════════════════════════════════════════════════╗
║   Obsidian KG Memory + Mac Agent Stack — Installer               ║
╠══════════════════════════════════════════════════════════════════╣
║   Will install / verify:                                         ║
║     0.   Pre-flight checks                                       ║
║     1.   Homebrew, Node 20, Python 3.11, git, jq                 ║
║     1.5  Touch ID for sudo (eliminates password prompts)         ║
║     2.   Claude Code CLI                                         ║
║     3.   OpenAI Codex CLI                                        ║
║     4.   Hermes Agent (NousResearch)                             ║
║     5.   Aqua Voice                                              ║
║     6.   Obsidian + Dataview plugin                              ║
║     7.   KG vault init + skills install                          ║
║     8.   Verification                                            ║
║     9.   Privacy & Security permissions (manual but batched)     ║
║                                                                  ║
║   Vault location: $KG_VAULT
║   State dir:      $STATE_DIR
║                                                                  ║
║   Idempotent — safe to re-run.                                   ║
╚══════════════════════════════════════════════════════════════════╝

EOF

if [[ "${OBSIDIAN_KG_NONINTERACTIVE:-0}" != "1" ]]; then
  if ! confirm "Proceed?"; then
    log "Aborted by user."
    exit 0
  fi
fi

# ── Preflight first ────────────────────────────────────────────────────────
log "Step: preflight"
PREFLIGHT_JSON="$("$SCRIPT_DIR/preflight.sh" 2>/dev/stderr || true)"
echo "$PREFLIGHT_JSON" > "$STATE_DIR/00-preflight.json"
if ! echo "$PREFLIGHT_JSON" | jq -e '.passed == true' >/dev/null; then
  log_err "Preflight failed. See $STATE_DIR/00-preflight.json and docs/AGENT-DEBUG.md."
  exit 1
fi

# ── Cache sudo upfront with keep-alive loop ───────────────────────────────
# This single prompt covers every sudo call in the install. Touch ID (next step)
# replaces this entirely on supported hardware.
log "Caching sudo credentials (one prompt for the whole install)"
sudo -v
# Keep-alive: refresh every 60s while installer is running.
( while true; do sudo -n true 2>/dev/null; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

# ── Steps to run, in order ─────────────────────────────────────────────────
steps=(
  "01-prereqs.sh"
  "01.5-touchid-sudo.sh"
  "02-claude-code.sh"
  "03-codex.sh"
  "04-hermes.sh"
  "05-aqua-voice.sh"
  "06-obsidian.sh"
  "07-kg-init.sh"
  "08-verify.sh"
  "09-permissions.sh"
)

declare -a steps_completed=() steps_skipped=() steps_failed=()

for step in "${steps[@]}"; do
  echo
  log "Step: $step"
  [[ -x "$SCRIPT_DIR/$step" ]] || chmod +x "$SCRIPT_DIR/$step"

  if "$SCRIPT_DIR/$step"; then
    # Inspect status JSON to classify.
    status_file="$STATE_DIR/${step%.sh}.json"
    if [[ -f "$status_file" ]]; then
      st=$(jq -r '.status' "$status_file" 2>/dev/null || echo "completed")
      case "$st" in
        completed) steps_completed+=("\"$step\"") ;;
        skipped)   steps_skipped+=("\"$step\"") ;;
        *)         steps_completed+=("\"$step\"") ;;
      esac
    else
      steps_completed+=("\"$step\"")
    fi
  else
    log_err "Step $step failed."
    steps_failed+=("\"$step\"")
    log "Inspect: $STATE_DIR/${step%.sh}.json"
    log "Recovery hints: docs/AGENT-DEBUG.md"
    # Print summary even on failure so the agent has something to act on.
    break
  fi
done

# ── Final summary JSON ─────────────────────────────────────────────────────
ORCHESTRATOR_END=$(date +%s)
TOTAL_DURATION=$(( ORCHESTRATOR_END - ORCHESTRATOR_START ))

if [[ ${#steps_failed[@]} -eq 0 ]]; then
  RESULT="success"
elif [[ ${#steps_completed[@]} -gt 0 ]]; then
  RESULT="partial"
else
  RESULT="failure"
fi

# Best-effort: detect remaining permissions from the permissions step JSON.
PERMS_REMAINING="[]"
if [[ -f "$STATE_DIR/09-permissions.json" ]]; then
  PERMS_REMAINING=$(jq -c '.result.skipped // []' "$STATE_DIR/09-permissions.json" 2>/dev/null || echo "[]")
fi

echo
echo "── Final summary ──────────────────────────────────────────────────"
SUMMARY_JSON=$(jq -nc \
  --arg result "$RESULT" \
  --argjson duration "$TOTAL_DURATION" \
  --argjson completed "[$(IFS=,; echo "${steps_completed[*]:-}")]" \
  --argjson skipped "[$(IFS=,; echo "${steps_skipped[*]:-}")]" \
  --argjson failed "[$(IFS=,; echo "${steps_failed[*]:-}")]" \
  --argjson perms_remaining "$PERMS_REMAINING" \
  --arg vault "$KG_VAULT" --arg state "$STATE_DIR" \
  '{result: $result, duration_seconds: $duration,
    steps_completed: $completed, steps_skipped: $skipped, steps_failed: $failed,
    permissions_remaining: $perms_remaining,
    vault_path: $vault, state_dir: $state,
    next_human_action: (if ($failed | length) > 0 then "Inspect state files in \($state); re-run failed steps after addressing errors"
                        elif ($perms_remaining | length) > 0 then "Grant remaining Aqua Voice permissions; re-run install/09-permissions.sh"
                        else "Open Obsidian, pick the vault at \($vault), then run `claude` and try /kg-add-note" end)}')
echo "$SUMMARY_JSON" | tee "$STATE_DIR/_summary.json"
echo
echo "── End ───────────────────────────────────────────────────────────"

if [[ "$RESULT" != "success" ]]; then
  exit 1
fi
