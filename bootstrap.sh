#!/usr/bin/env bash
# Takes a fresh Mac from nothing to a built nix-darwin config.
# Run this once. After it finishes, use ./rebuild.sh for every later change.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

echo "==> Step 1: Determinate Nix"
if command -v nix >/dev/null 2>&1; then
  echo "    nix already installed, skipping"
else
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

echo "==> Step 2: symlink this repo to ~/.dotfiles"
# home.nix resolves its mkOutOfStoreSymlink paths through ~/.dotfiles, so this
# has to exist before the first switch or the build will fail to find them.
ln -sfn "$DIR" ~/.dotfiles

echo "==> Step 3: personalize the configured username"
# Do this before any sudo call: sudo resets $USER to root, so whoami has to
# run as the real interactive user first.
REAL_USER="$(whoami)"
FLAKE_USER="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";.*/\1/p' "$DIR/flake.nix" | head -n1)"
if [ -z "$FLAKE_USER" ]; then
  echo "    Could not find the single \"user = \" line in flake.nix."
  echo "    Edit flake.nix yourself before continuing."
  exit 1
elif [ "$FLAKE_USER" != "$REAL_USER" ]; then
  echo "    flake.nix is configured for user \"$FLAKE_USER\", but you are \"$REAL_USER\"."
  read -r -p "    Rewrite flake.nix's \"user = \" line to \"$REAL_USER\"? [y/N] " REPLY
  if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
    sed -i '' -E "s/^([[:space:]]*user = \")[^\"]+(\";.*)/\1${REAL_USER}\2/" "$DIR/flake.nix"
    echo "    Updated. Review the change with: git diff flake.nix"
  else
    echo "    Skipped. Edit the single \"user = \" line in flake.nix yourself before continuing."
    exit 1
  fi
else
  echo "    flake.nix already matches \"$REAL_USER\", nothing to do."
fi

echo "==> Step 4: preserve local configuration and merge public defaults"
LOCAL_CONFIG_DIR="$HOME/.config/dotfiles-local"
mkdir -p "$LOCAL_CONFIG_DIR" "$LOCAL_CONFIG_DIR/pi-extensions"

copy_if_missing() {
  local source="$1"
  local fallback="$2"
  local destination="$3"
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    return
  fi
  if [ -e "$source" ] || [ -L "$source" ]; then
    cp -p "$source" "$destination"
  else
    cp -p "$fallback" "$destination"
  fi
}

# Keep personal or path-specific configuration outside this public repository.
copy_if_missing "$HOME/.claude/settings.json" "$DIR/home/.claude/settings.json" \
  "$LOCAL_CONFIG_DIR/claude-settings.json"
copy_if_missing "$HOME/.claude/CLAUDE.md" "$DIR/home/AGENTS.md" \
  "$LOCAL_CONFIG_DIR/claude-CLAUDE.md"
copy_if_missing "$HOME/.codex/AGENTS.md" "$DIR/home/AGENTS.md" \
  "$LOCAL_CONFIG_DIR/codex-AGENTS.md"
if [ ! -e "$LOCAL_CONFIG_DIR/zshrc" ] && [ ! -L "$LOCAL_CONFIG_DIR/zshrc" ]; then
  if [ -e "$HOME/.zshrc" ] || [ -L "$HOME/.zshrc" ]; then
    cp -p "$HOME/.zshrc" "$LOCAL_CONFIG_DIR/zshrc"
  else
    touch "$LOCAL_CONFIG_DIR/zshrc"
  fi
fi

# Merge existing local Pi extensions first, then add public repository-authored
# extensions without replacing same-named local entries.
if [ -d "$HOME/.pi/agent/extensions" ]; then
  for entry in "$HOME/.pi/agent/extensions"/*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    name="${entry##*/}"
    destination="$LOCAL_CONFIG_DIR/pi-extensions/$name"
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
      cp -R "$entry" "$destination"
    fi
  done
fi
for entry in "$DIR/home/.pi/agent/extensions"/*; do
  [ -e "$entry" ] || [ -L "$entry" ] || continue
  name="${entry##*/}"
  destination="$LOCAL_CONFIG_DIR/pi-extensions/$name"
  if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
    ln -s "$entry" "$destination"
  fi
done

echo "    Private local overlay ready at $LOCAL_CONFIG_DIR"

echo "==> Step 5: first darwin-rebuild switch (pinned to nix-darwin-26.05)"
# darwin-rebuild doesn't exist yet on a fresh machine, so run it straight
# from the flake this once. After this, rebuild.sh works normally.
# This fetches the darwin-rebuild tool from the nix-darwin-26.05 release branch,
# not the exact flake.lock revision. The system config it applies is still pinned
# by this repo's flake.lock.
# sudo resets PATH to a secure default that excludes /nix/.../bin, so a
# freshly installed `nix` would not be found under sudo even though it's
# on PATH here. Resolve the absolute path first and invoke that instead.
NIX_BIN="$(command -v nix)"
# "mac" is the flake host label - if you renamed it, change it in flake.nix
# and rebuild.sh too.
sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#mac
# If this still fails with "nix: command not found", open a new terminal
# (Determinate adds nix to new shells' PATH) and re-run ./bootstrap.sh.

echo "==> Done. Use ./rebuild.sh for future changes."
