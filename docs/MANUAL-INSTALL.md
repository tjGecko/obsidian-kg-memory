# Manual Install Reference

If `install/install-mac.sh` fails or you want to install something by hand, this is the underlying command list. Each section corresponds to a numbered script.

## 1. Prereqs

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add brew to PATH (Apple Silicon)
eval "$(/opt/homebrew/bin/brew shellenv)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile

# Xcode CLT
xcode-select --install

# Tools
brew install git jq node@20 python@3.11 pipx
brew link --overwrite --force node@20

# npm global prefix without sudo
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.zprofile
```

## 2. Claude Code

```bash
npm install -g @anthropic-ai/claude-code
claude --version
```

First run: `claude` opens an OAuth URL in your browser.

## 3. OpenAI Codex CLI

```bash
npm install -g @openai/codex
codex --version
codex login        # opens browser for OAuth
```

Or set the env var manually:
```bash
echo 'export OPENAI_API_KEY=sk-...' >> ~/.zprofile
```

## 4. Hermes Agent

```bash
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

# Hermes installs to ~/.local/bin — make sure it's on PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile

# Verify
hermes --version
```

Configure: edit `~/.hermes/config.yaml` (see `config/hermes-config.example.yaml` for the full reference). Add the OpenAI key to `~/.hermes/.env`:
```
OPENAI_API_KEY=sk-...
```

Then:
```bash
hermes setup     # walks you through provider/model
hermes           # starts a session
```

## 5. Aqua Voice

Apple Silicon:
```bash
curl -fL -o /tmp/aqua.dmg \
  https://aqua-desktop-builds.s3.us-east-1.amazonaws.com/aqua-voice-updates/stable/latest/Aqua-Voice-macOS-arm64.dmg
```

Intel:
```bash
curl -fL -o /tmp/aqua.dmg \
  https://aqua-desktop-builds.s3.us-east-1.amazonaws.com/aqua-voice-updates/stable/latest/Aqua-Voice-macOS-x64.dmg
```

Install:
```bash
hdiutil attach /tmp/aqua.dmg
cp -R "/Volumes/Aqua Voice/Aqua Voice.app" /Applications/
hdiutil detach "/Volumes/Aqua Voice"
xattr -dr com.apple.quarantine "/Applications/Aqua Voice.app"
open "/Applications/Aqua Voice.app"
```

Grant permissions in System Settings → Privacy & Security:
- Microphone
- Accessibility
- Input Monitoring

## 6. Obsidian + Dataview

```bash
brew install --cask obsidian

# Vault location (change to taste)
export KG_VAULT="$HOME/Documents/KG-Vault"
mkdir -p "$KG_VAULT/.obsidian/plugins"

# Dataview plugin
DV="$KG_VAULT/.obsidian/plugins/dataview"
mkdir -p "$DV"
RELEASE_JSON=$(curl -fsSL https://api.github.com/repos/blacksmithgu/obsidian-dataview/releases/latest)
for asset in main.js manifest.json styles.css; do
  URL=$(echo "$RELEASE_JSON" | jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .browser_download_url')
  curl -fsSL -o "$DV/$asset" "$URL"
done
echo '["dataview"]' > "$KG_VAULT/.obsidian/community-plugins.json"
```

Open Obsidian, point it at `$KG_VAULT`, trust the plugin when prompted.

## 7. KG vault init + skills install

```bash
# From the repo root
cp -R skills/kg-memory ~/.claude/skills/

# Seed vault
mkdir -p "$KG_VAULT/kg/"{notes,sources,topics}
TODAY=$(date +%Y-%m-%d)
for f in _index _timeline _dashboard; do
  sed -e "s/{{created}}/$TODAY/g" -e "s/{{updated}}/$TODAY/g" \
    "skills/kg-memory/templates/$f.md" > "$KG_VAULT/kg/$f.md"
done

# State file
cat > ~/.claude/kg_state.json <<EOF
{
  "schema_version": 1,
  "vault_path": "$KG_VAULT",
  "last_full_update": null,
  "cards": {},
  "stats": {"notes": 0, "sources": 0, "topics": 0, "total_pages": 3}
}
EOF
```

## 8. Verify

```bash
claude --version
codex --version
hermes --version
ls ~/.claude/skills/kg-memory/SKILL.md
ls "$KG_VAULT/kg/_index.md"
ls "$KG_VAULT/.obsidian/plugins/dataview/main.js"
```

If all five show up, you're good.
