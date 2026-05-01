#!/usr/bin/env bash
#
# Sync semgrep community rules from public upstream into the internal
# central rules repo as a reviewable PR. Runs on a DMZ host that has
# both internet egress (to clone github.com) and write access to internal
# git. Cron suggestion: weekly Monday 06:00 UTC.
#
#   0 6 * * 1  /opt/semgrep-sync/sync-upstream.sh >> /var/log/semgrep-sync.log 2>&1
#
# Outputs: a PR against the internal central rules repo containing the
# diff vs. the previous sync. Security team reviews and merges; merge
# triggers the next semgrep-rules tag.
#
# Exits 0 on success or no-op (no upstream changes). Non-zero on failure.

set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-https://github.com/returntocorp/semgrep-rules.git}"
UPSTREAM_REF="${UPSTREAM_REF:-develop}"
INTERNAL_REPO="${INTERNAL_REPO:-https://internal-git.example.com/appsec/semgrep-rules.git}"
WORKDIR="${WORKDIR:-/var/lib/semgrep-sync}"

# Subdirs to mirror from upstream into the internal repo's upstream/ tree.
# Add languages here as the org adopts them.
LANGS=(python java generic)

DATE_TAG="$(date -u +%Y%m%d)"
BRANCH="upstream-sync-${DATE_TAG}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "==> Fetching upstream"
if [ ! -d semgrep-rules-upstream ]; then
  git clone --depth 1 --branch "$UPSTREAM_REF" "$UPSTREAM_REPO" semgrep-rules-upstream
else
  git -C semgrep-rules-upstream fetch --depth 1 origin "$UPSTREAM_REF"
  git -C semgrep-rules-upstream reset --hard "origin/$UPSTREAM_REF"
fi

echo "==> Cloning internal central repo"
if [ ! -d semgrep-rules-internal ]; then
  git clone "$INTERNAL_REPO" semgrep-rules-internal
fi

cd semgrep-rules-internal
git fetch origin
git checkout -B "$BRANCH" origin/main

echo "==> Refreshing upstream/ tree"
rm -rf upstream
mkdir -p upstream
for lang in "${LANGS[@]}"; do
  if [ -d "../semgrep-rules-upstream/$lang" ]; then
    cp -r "../semgrep-rules-upstream/$lang" "upstream/$lang"
  else
    echo "WARN: upstream lacks $lang/, skipping" >&2
  fi
done

git add upstream
if git diff --cached --quiet; then
  echo "==> No upstream changes since last sync; exiting clean."
  exit 0
fi

UPSTREAM_SHA="$(git -C ../semgrep-rules-upstream rev-parse HEAD)"
git commit -m "chore: sync upstream semgrep-rules ${DATE_TAG}

Upstream: ${UPSTREAM_REPO}@${UPSTREAM_SHA}
"

echo "==> Pushing branch and opening PR"
git push -u origin "$BRANCH"

# Replace `gh` with `glab`, `tea`, or whatever CLI matches your internal
# git host. The reviewer slug must match a CODEOWNERS-recognised group.
gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "Upstream rules sync ${DATE_TAG}" \
  --body "Automated sync from ${UPSTREAM_REPO} (ref: ${UPSTREAM_REF}, sha: ${UPSTREAM_SHA}).

Security team to review the diff before merge. Look for:
  - new rules with high FP risk on our codebase
  - severity bumps that would tip findings into the blocking gate
  - removed rules that were previously catching real findings

Merge cuts the next semgrep-rules tag." \
  --reviewer org/appsec
