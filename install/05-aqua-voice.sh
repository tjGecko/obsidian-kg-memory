#!/usr/bin/env bash
# 05-aqua-voice.sh — Download and install the Aqua Voice macOS app.
# Picks the architecture-correct .dmg, mounts, copies to /Applications.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"
require_macos

STEP_NAME="05-aqua-voice"
step_start
step_trap_err

if [[ -d "/Applications/Aqua Voice.app" ]]; then
  log_skip "Aqua Voice already installed at /Applications/Aqua Voice.app"
  step_skip "already installed at /Applications/Aqua Voice.app"
  exit 0
fi

case "$(arch)" in
  arm64)  DMG_URL="https://aqua-desktop-builds.s3.us-east-1.amazonaws.com/aqua-voice-updates/stable/latest/Aqua-Voice-macOS-arm64.dmg" ;;
  x86_64) DMG_URL="https://aqua-desktop-builds.s3.us-east-1.amazonaws.com/aqua-voice-updates/stable/latest/Aqua-Voice-macOS-x64.dmg" ;;
  *)      log_err "Unsupported arch: $(arch)"; exit 1 ;;
esac

SCRATCH="$INSTALL_DIR/.scratch"
ensure_dir "$SCRATCH"
DMG_PATH="$SCRATCH/Aqua-Voice.dmg"

STEP_ERROR_CODE="download_fail"
log "Downloading Aqua Voice for $(arch)"
curl -fL --progress-bar -o "$DMG_PATH" "$DMG_URL"
STEP_ERROR_CODE=""

STEP_ERROR_CODE="dmg_mount_fail"
log "Mounting $DMG_PATH"
MOUNT_POINT="$(hdiutil attach -nobrowse -quiet "$DMG_PATH" | tail -1 | awk '{$1=$1; for (i=3;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')"
if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  log_err "Failed to determine mount point for the .dmg"
  exit 1
fi
STEP_ERROR_CODE=""

APP_SRC="$(find "$MOUNT_POINT" -maxdepth 2 -name 'Aqua Voice.app' -print -quit || true)"
if [[ -z "$APP_SRC" ]]; then
  log_err "Could not find 'Aqua Voice.app' inside the mounted .dmg"
  hdiutil detach -quiet "$MOUNT_POINT" || true
  exit 1
fi

log "Copying to /Applications"
cp -R "$APP_SRC" /Applications/

log "Detaching .dmg"
hdiutil detach -quiet "$MOUNT_POINT" || true
rm -f "$DMG_PATH"

# Clear the macOS quarantine flag so the app opens without the "downloaded from internet" warning.
xattr -dr com.apple.quarantine "/Applications/Aqua Voice.app" 2>/dev/null || true

log_ok "Aqua Voice installed."

cat <<EOF

  ${C_YELLOW}Manual steps required:${C_RESET}

    1. Open /Applications/Aqua Voice.app.
    2. macOS will request these permissions — grant them in System Settings → Privacy & Security:
         • Microphone
         • Accessibility (so it can type into other apps)
         • Input Monitoring (for the global hotkey)
    3. Set your push-to-talk hotkey in Aqua Voice → Preferences.
    4. Sign in with your Aqua Voice account (free tier is sufficient to start).

EOF

step_complete '{"installed": true, "path": "/Applications/Aqua Voice.app", "permissions_required": ["microphone", "accessibility", "input_monitoring"]}'
