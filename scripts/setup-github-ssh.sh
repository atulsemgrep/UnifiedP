#!/usr/bin/env bash
# Run this in Terminal.app (or Cursor’s integrated terminal), NOT in a restricted agent sandbox.
# It finishes GitHub SSH setup: keys, ssh config, known_hosts, agent, test, optional gh upload.
set -euo pipefail

umask 077
mkdir -p ~/.ssh
chmod 700 ~/.ssh

KEY="${HOME}/.ssh/id_ed25519"
PUB="${KEY}.pub"

if [[ ! -f "$KEY" ]]; then
  echo "Creating Ed25519 key at $KEY"
  ssh-keygen -t ed25519 -C "$(whoami)@$(hostname -s 2>/dev/null || echo mac)-bad-python-app" -f "$KEY" -N ""
fi

CONFIG="${HOME}/.ssh/config"
if [[ -f "$CONFIG" ]] && grep -q '^Host github.com' "$CONFIG" 2>/dev/null; then
  echo "Keeping existing github.com block in ~/.ssh/config"
else
  cat >>"$CONFIG" <<'EOF'

# GitHub (bad-python-app setup script)
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  AddKeysToAgent yes
  UseKeychain yes
EOF
  chmod 600 "$CONFIG"
  echo "Appended github.com block to ~/.ssh/config"
fi

# Avoid first-connection host key prompt in batch-ish runs
if ! grep -q '^github.com' ~/.ssh/known_hosts 2>/dev/null; then
  touch ~/.ssh/known_hosts
  chmod 600 ~/.ssh/known_hosts
  ssh-keyscan -t rsa,ecdsa,ed25519 github.com >>~/.ssh/known_hosts 2>/dev/null || true
  echo "Updated ~/.ssh/known_hosts with github.com"
fi

# Load key into agent (reuse existing agent when possible — e.g. macOS login session)
if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
  echo "Using existing SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
else
  echo "Starting ssh-agent…"
  eval "$(ssh-agent -s)" >/dev/null || {
    echo "Could not start ssh-agent in this environment."
    echo "Open Terminal.app (outside restricted sandboxes) and run this script again."
    exit 2
  }
fi
if [[ "$(uname -s)" == "Darwin" ]]; then
  ssh-add --apple-use-keychain "$KEY" 2>/dev/null || ssh-add "$KEY" || {
    echo "ssh-add failed; try: ssh-add --apple-use-keychain $KEY"
    exit 2
  }
else
  ssh-add "$KEY" || exit 2
fi

echo ""
echo "=== Testing SSH to GitHub ==="
set +e
OUT=$(ssh -o BatchMode=yes -T git@github.com 2>&1)
RC=$?
set -e
echo "$OUT"

if [[ $RC -eq 1 ]] && echo "$OUT" | grep -qi 'successfully authenticated'; then
  echo ""
  echo "SSH to GitHub is working."
elif [[ $RC -eq 255 ]]; then
  echo ""
  echo "Could not connect (network or DNS). Check Wi‑Fi / VPN / firewall."
  exit 1
else
  echo ""
  echo "If you see 'Permission denied (publickey)', add this key to GitHub:"
  echo "  https://github.com/settings/ssh/new"
  echo ""
  cat "$PUB"
  echo ""
  command -v pbcopy >/dev/null && pbcopy <"$PUB" && echo "(Public key copied to clipboard.)"
  if command -v gh >/dev/null 2>&1; then
    echo ""
    echo "After 'gh auth login' works, you can add this key non-interactively:"
    echo "  gh ssh-key add \"$PUB\" --title \"$(hostname -s 2>/dev/null || hostname) $(date +%Y-%m-%d)\""
  fi
  exit 1
fi

if command -v gh >/dev/null 2>&1; then
  if gh auth status -h github.com &>/dev/null; then
    echo ""
    echo "=== gh is logged in; ensuring SSH key is registered (skips if duplicate) ==="
    gh ssh-key add "$PUB" --title "$(hostname -s 2>/dev/null || hostname) $(date +%Y-%m-%d)" 2>/dev/null || echo "(Key may already exist on GitHub; that is OK.)"
  else
    echo ""
    echo "=== gh: token missing or invalid — run once: ==="
    echo "  gh auth login -h github.com -s git_write -s read:org"
    echo "Then re-run this script, or run:"
    echo "  gh ssh-key add \"$PUB\" --title \"$(hostname -s 2>/dev/null || hostname)\""
  fi
fi

echo ""
echo "Done. You can push with:"
echo "  cd \"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)\" && git push -u origin \$(git branch --show-current)"
