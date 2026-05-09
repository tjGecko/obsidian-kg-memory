#!/usr/bin/env bash
# 09-permissions.sh — Bundle every macOS Privacy & Security permission grant
# into one phase at the end of install.
#
# Apple TCC by design cannot be scripted — the user must physically toggle each
# switch in System Settings. This script minimizes the pain by:
#   1. Opening the right panel via deep-link
#   2. Speaking an audio cue so the user knows which switch to flip
#   3. Walking through ALL permissions in one continuous sequence
#
# Skips automatically if OBSIDIAN_KG_SKIP_TCC=1 is set (e.g., headless/CI runs).

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

STEP_NAME="09-permissions"
step_start
step_trap_err

if [[ "${OBSIDIAN_KG_SKIP_TCC:-0}" == "1" ]]; then
  log_warn "OBSIDIAN_KG_SKIP_TCC=1 — skipping permissions phase. Aqua Voice WILL NOT WORK until permissions are granted manually."
  step_skip "OBSIDIAN_KG_SKIP_TCC=1"
  exit 0
fi

# Speak via macOS `say` command if available (audio cue).
speak() {
  if have_cmd say; then
    say -v "Samantha" "$1" &
    SAY_PID=$!
  fi
}

wait_for_speak() {
  if [[ -n "${SAY_PID:-}" ]]; then
    wait "$SAY_PID" 2>/dev/null || true
  fi
  SAY_PID=""
}

prompt_grant() {
  # prompt_grant <label> <pane-anchor> <spoken-instruction>
  local label="$1"
  local anchor="$2"
  local spoken="$3"

  echo
  log "→ $label"
  speak "$spoken"
  open "x-apple.systempreferences:com.apple.preference.security?$anchor" 2>/dev/null || true
  wait_for_speak

  printf "Press ENTER once you've enabled %s in System Settings (or 's' to skip): " "$label"
  read -r reply
  if [[ "$reply" =~ ^[Ss] ]]; then
    log_warn "$label skipped by user"
    return 1
  fi
  log_ok "$label confirmed"
  return 0
}

cat <<EOF

╔══════════════════════════════════════════════════════════════════╗
║   Final step: macOS Privacy & Security permissions               ║
╠══════════════════════════════════════════════════════════════════╣
║   Apple requires you to grant these by hand — they cannot be     ║
║   scripted. This phase walks through them in one go.             ║
║                                                                  ║
║   For each: System Settings will open to the right panel.        ║
║   Find "Aqua Voice" in the list and toggle it ON.                ║
║   Then come back here and press ENTER.                           ║
║                                                                  ║
║   Total: 3 permissions, ~30 seconds each.                        ║
╚══════════════════════════════════════════════════════════════════╝

EOF

if ! confirm "Ready to grant Aqua Voice permissions?"; then
  log "Aborted by user. Re-run install/09-permissions.sh when ready."
  step_skip "user declined to grant permissions"
  exit 0
fi

declare -a granted=() skipped=()

# ── 1. Microphone ─────────────────────────────────────────────────────────
if prompt_grant "Microphone" "Privacy_Microphone" \
  "Please enable the microphone toggle for Aqua Voice."; then
  granted+=('"microphone"')
else
  skipped+=('"microphone"')
fi

# ── 2. Accessibility ──────────────────────────────────────────────────────
if prompt_grant "Accessibility" "Privacy_Accessibility" \
  "Please enable the accessibility toggle for Aqua Voice. This lets it type into other apps."; then
  granted+=('"accessibility"')
else
  skipped+=('"accessibility"')
fi

# ── 3. Input Monitoring ───────────────────────────────────────────────────
if prompt_grant "Input Monitoring" "Privacy_ListenEvent" \
  "Please enable the input monitoring toggle for Aqua Voice. This is for the global hotkey."; then
  granted+=('"input_monitoring"')
else
  skipped+=('"input_monitoring"')
fi

echo
if [[ ${#skipped[@]} -eq 0 ]]; then
  log_ok "All 3 permissions granted."
else
  log_warn "${#granted[@]} granted, ${#skipped[@]} skipped: ${skipped[*]}"
  log_warn "Aqua Voice will not function fully until skipped permissions are granted."
fi

cat <<EOF

  Final manual steps (one-time):

    • Open Aqua Voice (it's now in /Applications) and sign in.
    • Set your push-to-talk hotkey in Aqua Voice → Preferences.
    • Run \`claude\` for the first time to OAuth with Anthropic.
    • If you haven't yet, edit ~/.hermes/.env and add OPENAI_API_KEY=sk-...

  You're done. Try: claude /kg-add-note "this is my first captured thought"

EOF

step_complete "$(jq -nc \
  --argjson granted "[$(IFS=,; echo "${granted[*]:-}")]" \
  --argjson skipped "[$(IFS=,; echo "${skipped[*]:-}")]" \
  '{granted: $granted, skipped: $skipped, total: 3}')"
