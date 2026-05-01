# semgrep-rules (bootstrap)

This directory is a **seed for a separate internal repo**, not part of the
`bad-python-app` codebase. It exists here only so it can be reviewed and
extracted in one step. Once extracted, delete it from `bad-python-app`.

## What this becomes

The central rules repo for an air-gapped Semgrep deployment. One source of
truth, owned by the security team, consumed by every app repo via a pinned
tag in their `semgrep-airgapped.yml` workflow.

## Extracting

```sh
# 1. Move the seed out of the consumer repo
cp -r semgrep-rules-bootstrap /tmp/semgrep-rules
cd /tmp/semgrep-rules

# 2. Initialise as a standalone repo
git init -b main
git add .
git commit -m "Initial rules"

# 3. Push to internal git (replace URL with your instance)
git remote add origin https://internal-git.example.com/appsec/semgrep-rules.git
git push -u origin main

# 4. Cut the first release
git tag v2026.04.0
git push origin v2026.04.0

# 5. Remove the bootstrap from the consumer repo
cd -
git rm -r semgrep-rules-bootstrap
git commit -m "chore: remove rules bootstrap (extracted to appsec/semgrep-rules)"
```

After step 4, every consumer repo's `semgrep-airgapped.yml` references
`appsec/semgrep-rules@v2026.04.0` and the central pipeline is live.

## Layout

```
.
├── python/        # python-specific rules
├── shared/        # cross-language (secrets, generic injection patterns)
├── sync/          # DMZ sync script — pulls upstream rules into a PR
├── CODEOWNERS     # security team owns everything
├── .semgrepignore # paths ignored regardless of consumer repo settings
└── README.md
```

## Adding a rule

1. Open a PR. Include in the description: what the rule catches, expected
   FP rate, links to one or two real findings the rule would have caught
   on representative repos.
2. CODEOWNERS routes review to `@org/appsec`.
3. On merge, cut a new tag (`vYYYY.MM.N`) and push. Consumer repos pick
   up the new rules when they bump their pin.

## Release cadence

- **Monthly tags** for routine rule additions/tweaks.
- **Out-of-band tags** for security-critical pushes (e.g. a new rule
  detecting an active in-the-wild exploit pattern). Communicate to
  consumers via the usual channel and have them open a pin-bump PR.

## Sync from upstream

The `sync/` directory contains a script (run from a DMZ host with internet
egress) that mirrors `returntocorp/semgrep-rules` into `upstream/` and
opens a PR. Security team reviews the diff before merging — that review is
what compensates for losing Semgrep Cloud's rule policy UI in the air gap.
See `sync/README.md` for operational detail.
