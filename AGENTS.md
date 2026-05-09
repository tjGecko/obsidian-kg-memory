# AGENTS.md — Entry point for autonomous agents

> If you are a human, read [`README.md`](README.md) instead. This file is written for an AI agent that has been handed only the URL of this repo and asked to install the stack on a macOS machine.

## Your job

Install and configure the full stack (KG memory + agent CLIs + Obsidian + Aqua Voice) on the macOS machine you're running on. Verify the install. Report status. Don't ask the human anything you can determine yourself.

## Read these files in this order

1. **`AGENTS.md`** — this file
2. **`README.md`** — system overview
3. **`ARCHITECTURE.md`** — how the layers fit
4. **`docs/AGENT-DEBUG.md`** — failure-mode → recovery table (read on any failure)
5. **`docs/SCHEMA.md`** + **`docs/CARD-RULES.md`** — reference, only if a `/kg-*` skill behaves unexpectedly

Do **not** read `docs/MOM-CHEATSHEET.md` or `docs/HELPER-RUNBOOK.md` — those are written for humans and will waste your context.

## Execution protocol

```
1. Run install/preflight.sh   → must exit 0; if not, follow recovery in AGENT-DEBUG.md
2. Run install/inventory.sh   → parse JSON; identify gap set
3. Cache sudo: sudo -v        → keep-alive loop (orchestrator handles this)
4. Run install/install-mac.sh → orchestrates all steps; writes per-step JSON status
5. After completion, run install/inventory.sh again → assert no gaps remain
6. Report a single JSON object summarizing: { steps_run, steps_skipped, steps_failed, total_duration_sec, gaps_remaining }
```

If you only need to run a subset of steps, each `install/NN-*.sh` script is independently runnable and idempotent. Do not invent your own ordering — the numbers reflect dependencies.

## State directory

Every step writes a status JSON to `install/.state/<step-name>.json`. The schema:

```json
{
  "step": "04-hermes",
  "status": "started | completed | skipped | failed",
  "started_at": "2026-05-09T14:32:01Z",
  "finished_at": "2026-05-09T14:33:45Z",
  "duration_seconds": 104,
  "result": { "installed": true, "version": "0.12.0", "path": "/Users/tj/.local/bin/hermes" },
  "error": null
}
```

On failure, `error` is `{ "code": "<short-token>", "message": "<human msg>", "recovery_hint": "<command-or-doc-ref>" }`. The `code` is your dispatch key against [`docs/AGENT-DEBUG.md`](docs/AGENT-DEBUG.md).

## Environment variables you can set

| Var | Default | Purpose |
|---|---|---|
| `KG_VAULT` | `~/Documents/KG-Vault` | Where the Obsidian vault lives |
| `OBSIDIAN_KG_NONINTERACTIVE` | `0` | Set to `1` to skip every confirm prompt (use only when you've already verified pre-conditions) |
| `OBSIDIAN_KG_SKIP_TCC` | `0` | Set to `1` to skip the manual permissions phase (e.g., when running headless; warn human afterward) |
| `OBSIDIAN_KG_PIN_VERSIONS` | `0` | Set to `1` to use exact versions from `install/versions.env` instead of latest |

The orchestrator sets `NONINTERACTIVE=1`, `HOMEBREW_NO_AUTO_UPDATE=1`, and `HOMEBREW_NO_ENV_HINTS=1` for any sub-process; you don't need to set these.

## What requires a human

These cannot be automated by design (Apple TCC). Surface them to the human at the **end** of the install in one batch, not interspersed:

1. Aqua Voice → Microphone permission
2. Aqua Voice → Accessibility permission
3. Aqua Voice → Input Monitoring permission
4. Aqua Voice → Sign in (account creation)
5. Claude Code first-run → OAuth in browser
6. (Optional) `codex login` → OAuth in browser, *unless* `OPENAI_API_KEY` is in env
7. Edit `~/.hermes/.env` to add `OPENAI_API_KEY=sk-...` *unless* you put it there yourself

The `09-permissions.sh` script bundles 1–3 with deep-links. The rest happen on first use of each app.

## What you should NOT do

- **Don't `sudo rm -rf` anything.** If a step says cleanup is needed, use the targeted commands in `uninstall-mac.sh`.
- **Don't write to the user's vault** beyond the seed files in `kg/_index.md`, `kg/_timeline.md`, `kg/_dashboard.md`. The vault is the user's data.
- **Don't disable SIP, Gatekeeper, or System Settings → Privacy & Security toggles.** If a step asks you to, abort and flag.
- **Don't set `OPENAI_API_KEY` system-wide if you're given one** — write it only to `~/.hermes/.env` (chmod 600). Same for any other secret.
- **Don't OAuth login on the user's behalf** — the credentials would belong to you, not them.

## Recovery from partial install

If `install/.state/` already exists when you start, you're resuming. Behavior:

- For each step with `status: completed` in its JSON: skip.
- For each step with `status: failed`: re-run; check `AGENT-DEBUG.md` for the error code first.
- For each step with `status: started` (incomplete — process killed): treat as `failed`.

To start fresh: `rm -rf install/.state/` and re-run.

## Verification

`install/08-verify.sh` runs ten read-only checks and exits non-zero if any fail. After install, you must run it. After permissions phase, run `install/inventory.sh` to confirm permission grants where detectable (microphone access can be checked via `system_profiler SPApplicationsDataType` or `tccutil`).

## Final report format

After completing the install, output exactly one JSON object on stdout:

```json
{
  "result": "success | partial | failure",
  "duration_seconds": 712,
  "steps_run": ["00-preflight", "01-prereqs", "01.5-touchid-sudo", ...],
  "steps_skipped": ["02-claude-code"],
  "steps_failed": [],
  "permissions_remaining": ["aqua_voice_microphone", "aqua_voice_accessibility"],
  "next_human_action": "Open Aqua Voice and grant the three Privacy permissions when prompted",
  "vault_path": "/Users/tj/Documents/KG-Vault"
}
```

Then stop.
