#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# On the first run darwin-rebuild is not installed yet. On later runs it may
# exist in a user-managed Nix profile that sudo does not include in PATH.
if DARWIN_REBUILD="$(command -v darwin-rebuild 2>/dev/null)"; then
  exec sudo "$DARWIN_REBUILD" switch --flake ~/.dotfiles#mac
fi

NIX_BIN="$(command -v nix 2>/dev/null || true)"
if [ -z "$NIX_BIN" ] && [ -x /nix/var/nix/profiles/default/bin/nix ]; then
  NIX_BIN=/nix/var/nix/profiles/default/bin/nix
fi
if [ -z "$NIX_BIN" ]; then
  echo "nix is not available; source the Determinate Nix profile and retry" >&2
  exit 1
fi

exec sudo "$NIX_BIN" run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- \
  switch --flake ~/.dotfiles#mac
