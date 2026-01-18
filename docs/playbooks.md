# Playbooks

This repo uses small, focused playbooks that import roles. All playbooks load
vars from `vars/environments/` and `vars/stack/` (plus platform/site specifics
when needed).

## Server lifecycle
`playbooks/server.yml`
- Purpose: Base OS configuration, security hardening, verification, updates.
- Hosts: `managed`
- Tags:
  - `install` -> `server_install`
  - `secure` -> `server_secure`
  - `verify` -> `server_verify`
  - `update` -> `server_update`
- Notes: Must pass at least one tag or the play ends early.

## Platform lifecycle
`playbooks/platform.yml`
- Purpose: Install/update/verify/delete/backup/restore/clone Drupal platforms.
- Hosts: `lamp`
- Tags:
  - `install` -> `platform_install` + `platform_verify`
  - `update` -> `platform_update`
  - `verify` -> `platform_verify`
  - `delete` -> `platform_delete`
  - `backup` -> `platform_backup`
  - `restore` -> `platform_restore`
  - `clone` -> `platform_clone`
- Required vars: `-e "platform=<platform_id>"`
- Notes: Enforces a single-host limit (`--limit <host>`), and will exit if no tags are set.

## Site lifecycle
`playbooks/site-*.yml`
- `site-install.yml` -> install + login link generation
- `site-update.yml` -> update + verify
- `site-verify.yml` -> verify only
- `site-backup.yml` -> backup only
- `site-restore.yml` -> restore only
- `site-delete.yml` -> delete only
- `site-login.yml` -> login link only
- `site-migrate.yml` -> migrate a site to another platform

Shared behavior
- Hosts: `lamp`
- Required vars: `-e "site=<site_id>"`
- Optional vars:
  - `site_migrate_target_platform` (or `site_target_platform`) for migration
  - `site_restore_timestamp` for restores (defaults to latest)
- Notes: Site playbooks load `vars/stack/drupal/<stack.drupal>.yml`. Ensure the
  chosen `stack.drupal` value has a matching file.

## Test playbooks
`playbooks/tests/*.yml`
- `network-probe.yml` - network reachability checks
- `cloudflare-api-probe.yml` - Cloudflare API access
- `cloudflare-pinned-probe.yml` - Cloudflare cert/key validation
- `control-probe.yml` - control node checks

## Common CLI flags
- `-i inventory/<env>/hosts.yml` to select environment
- `-l <host|group>` to limit scope
- `--tags <taglist>` required for server/platform playbooks
- `--ask-vault-pass` or `--vault-password-file` when vaults are used
