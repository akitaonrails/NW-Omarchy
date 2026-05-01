# Migrations

Each file here is a one-shot upgrade step keyed by the **target** version it brings the system into. `nw-omarchy-upgrade` executes every migration whose target is **strictly greater than** the user's current version and **less than or equal to** the new latest.

## Naming

```
migrations/<target-version>.sh   e.g.  migrations/1.1.sh
                                       migrations/1.2.sh
                                       migrations/2.0.sh
```

Versions follow [semver](https://semver.org/) and must match a corresponding git tag (`v<version>`). Versions are compared with `sort -V`.

## Ordering

`nw-omarchy-upgrade` runs migrations in lexical-versionsort order. If you upgrade `1.0 → 1.3`, you get:

```
migrations/1.1.sh   →   migrations/1.2.sh   →   migrations/1.3.sh
```

each run in turn. Skip migrations are not allowed — every step in the chain runs.

## Conventions

- **Idempotent.** A migration must be safe to re-run. Don't assume any prior state beyond what previous migrations or the install pipeline have established.
- **Self-contained.** No sourcing of helpers from `bin/` — those scripts may have been replaced by the new install pipeline that runs *after* this migration.
- **Stay surgical.** Migrations are for upgrade-specific concerns (file moves, config schema bumps, package replacements that pacman can't resolve automatically). General install convergence still happens via `install.sh --apply`, which runs after all migrations.
- **Exit non-zero on failure.** `nw-omarchy-upgrade` aborts the chain if a migration exits non-zero, leaving the version stamp at the last successful version so a re-run picks up where it left off.
- **Comment heavily.** Migrations are read in anger when something breaks. Explain *why* the change is needed, not just what it does.

## When NOT to write a migration

- Pure code changes that the install pipeline picks up automatically (configs in `default/`, new `bin/` helpers, sxhkd binding edits, etc.) — these are handled by `install.sh --apply` which `nw-omarchy-upgrade` always runs after migrations. No migration script needed.
- Adding a new package to `packages/nw-omarchy.packages` — `install/packages.sh` handles it.
- Removing a package — add it to `PRE_INSTALL_REMOVE` in `install/packages.sh`. (For pre-1.0 leftover predecessors. Post-1.0, removal goes here.)

## Skeleton

```bash
#!/usr/bin/env bash
# migrations/X.Y.sh — concise summary of what changes between (X.Y - prev) and X.Y.
#
# Why: <reason>
# Affects: <files / configs / packages>

set -euo pipefail

# Idempotency guard — if the work is already done, exit 0.
if [ -f "$HOME/.config/.../already-migrated" ]; then
    exit 0
fi

# … the actual work …
```
