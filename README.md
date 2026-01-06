# ansible-drupal
Infrastructure-as-code for building and running Drupal platforms on Ubuntu hosts.

## Repository Layout
- `inventory/` – per-environment inventories (`dev/`, `prod/`) each with `hosts.yml`, `group_vars/`, `host_vars/`, and vaults.
- `playbooks/` – task-specific entry points: `server.yml`, the consolidated `platform.yml` (installs, updates, verifies, or deletes platforms via tags), the `site-*.yml` lifecycle playbooks, and the legacy aggregators (`servers.yml`, `platforms.yml`, `sites.yml`). Backwards-compatibility wrappers (`platform-install.yml`, etc.) simply import `platform.yml`.
- `roles/` – decomposed roles for each lifecycle stage (server\_\*, os_apache, os_mysql, os_php, platform\_\*, site\_\*, etc.). Shared templates/handlers now live with their owning role.
- `ansible.cfg` – default Ansible settings (inventory, roles path, user, etc.).
- `LICENSE` and `README.md`.

## Choosing an Inventory
Each environment has its own inventory root:
```
inventory/
  dev/
    hosts.yml
    group_vars/
      all.yml
      clientAP/
      clientMH/
      control/
    host_vars/
      ap-ctrl01.yml
      ap-host01.yml
      mh-host05.yml
  prod/
    hosts.yml
    group_vars/
      all.yml
      clientAP/
      clientMH/
      control/
    host_vars/
      ap-ctrl01.yml
      ap-host09.yml
      mh-host03.yml
      mh-host04.yml
```
The default inventory points at `inventory/dev/hosts.yml`; use `-i inventory/prod/hosts.yml` to target prod. You can still limit within an inventory (`-l dev`, `-l clientAP`, `-l ap-host01`).

## Running Playbooks
Common examples (always include `--ask-vault-pass` or `--vault-password-file` when secrets are stored in the vault):
```sh
# Harden/patch servers
ansible-playbook playbooks/server.yml --tags "install,secure" -i inventory/dev/hosts.yml
ansible-playbook playbooks/server.yml --tags "install,secure" -i inventory/prod/hosts.yml -l clientAP

# Provision or update Drupal codebases (use --tags install|update|verify|delete|backup|restore)
# Platform operations enforce a single-host scope, so always limit the play to one host.
ansible-playbook playbooks/platform.yml --limit ap-host01 --tags install -e "platform=d11_standard" -i inventory/dev/hosts.yml
ansible-playbook playbooks/platform.yml --limit ap-host01 --tags update -i inventory/dev/hosts.yml
ansible-playbook playbooks/platform.yml --limit ap-host01 --tags backup -e "platform=d11_standard" -i inventory/dev/hosts.yml
ansible-playbook playbooks/platform.yml --limit ap-host01 --tags restore -e "platform=d11_standard" -e "platform_restore_archive=/home/d11user/backup/d11_standard/d11_standard-20240101T000000.tar.gz" -i inventory/dev/hosts.yml

# Manage Drupal sites
ansible-playbook playbooks/site-install.yml --tags install -e "site=client1_main_ap_dev" -i inventory/dev/hosts.yml
ansible-playbook playbooks/site-update.yml --tags update -e "site=client1_main_ap_dev" -i inventory/dev/hosts.yml
ansible-playbook playbooks/site-login.yml -e "site=client1_main_ap_dev" -i inventory/dev/hosts.yml
ansible-playbook playbooks/site-backup.yml --tags backup -e "site=client1_main_ap_dev" -i inventory/dev/hosts.yml
ansible-playbook playbooks/site-migrate.yml --limit ap-host01 -e "site=client1_main_ap_dev" -e "site_migrate_target_platform=d11_standard" -i inventory/dev/hosts.yml
ansible-playbook playbooks/site-restore.yml --limit ap-host01 -e "site=client1_main_ap_dev" -e "site_restore_timestamp=20251207-1417" -i inventory/dev/hosts.yml
```
- Site backups write `database.sql` and `files.tar.gz` under `/home/<platform_user>/backup/<platform_id>/<site>/<YYYYMMDD-HHMM>/`. Restore by providing the timestamp (`-e "site_restore_timestamp=20240101-1200"`), which derives that path; if omitted, the latest dated directory is used automatically.
 - Fresh site installs always enable Drupal's `syslog` module and uninstall `dblog` so events go to the host's syslog.
- To auto-enable modules on install, set `site_install_default_modules` globally, `site_install_modules` in a platform definition, or `modules_enable` for a specific site entry; the role picks the site value first, then platform, then global, and runs `drush pm-enable` accordingly. Use `modules_disable` under a site to uninstall modules right after install (for example, default sites list `dblog` there while `modules_enable` contains `syslog`).

## Platform Definitions
- All supported Drupal platform blueprints live in `vars/platforms/<family>/*.yml` (for example `vars/platforms/drupal11/drupal11.yml`). Each file defines exactly one platform entry mapping to a Composer-driven Drupal core copy.
- Common Drupal defaults (base path, composer project, profile, version, permissions, etc.) live in `vars/platforms/platform.yml` and are imported automatically by the platform playbook.
- All Drupal platform codebases are deployed under `/var/www/drupal/<platform_id>` by default. Override `platform_base_dir.path` (and its owner/group/mode attributes as needed) to relocate or customize permissions for the upstream directory.
- Every host that participates in the `lamp` group must declare a `platforms` mapping in its `inventory/<env>/host_vars/<host>.yml`, keyed by platform identifier with the Unix `user`/`group` data as the value, for example:
  ```yaml
  platforms:
    drupal11:
      user: d11user
      group: d11user
    drupal10_4:
      user: d10user
      group: d10user
  ```
- Provide `-e "platform=<id>"` when running `playbooks/platform.yml` to choose which platform to operate on; there is no implicit default. The playbook merges the selected platform definition with the host-specific attributes so downstream roles can rely on `platform_item.value.user`/`group`. A host's list must be a subset of `vars/platforms`.
- To add a new platform, drop a YAML file under `vars/platforms/` with the desired attributes (composer project, profile, version) and reference its ID from the appropriate hosts.

## Site Definitions
- All Drupal sites live alongside each environment's inventory under `inventory/<env>/host_vars/<host>/sites.d/*.yml`. Each file declares a `sites` mapping keyed by a unique identifier for that environment.
- Each site entry must set `name` to the public FQDN for that Drupal site (for example `example.com` or `www.example.com`). The legacy `fqdn` attribute has been removed—use `name` wherever a hostname is required.
- Site playbooks only act on hosts that define the requested site key under their `sites` mapping.
- Every site playbook requires `-e "site=<site_identifier>"` on the CLI, where the value is the inventory key declared under `sites`. Hosts that do not define the selected site automatically skip execution.
- Database credentials are read from each site's `settings.php` on the managed node (`$databases['default']['default']`); inventory no longer supplies `db_name`, `db_user`, or `db_password`.
- Admin account passwords are no longer stored in inventory; fresh installs generate a random admin password and you should use `playbooks/site-login.yml` (or `drush user:login`) to obtain a login URL after provisioning.
- Each site entry should define a `cf` (Cloudflare) block when SSL automation is desired:
  ```yaml
    cf:
      zone_id: "{{ vault_client1_cf_zone_id | default('dummy') }}"
      email: "{{ vault_client1_cf_email | default('admin@example.com') }}"
      api_key: "{{ vault_client1_cf_api_key | default('dummy') }}"
      private_key: "{{ vault_client1_cf_private_key | default('') }}"
  ```
  The SSL role falls back to self-signed certificates whenever `zone_id` remains `dummy`.
- To move a site between platforms, run `playbooks/site-migrate.yml` with `-e "site=<id>" -e "site_migrate_target_platform=<platform>"`. The playbook locates the latest site backup under the current platform, restores it onto the target platform, and reapplies ownership/permissions. Update the site's `platform` entry in `inventory/*/host_vars/*/sites.d/*.yml` after migration so future runs target the new location.

## Platform Backups and Restores
- Use `--tags backup` to capture a tarball of the Drupal code under `/home/<platform_user>/backup/<platform_id>/<timestamp>.tar.gz`. Backups skip client site directories under `web/sites/` while keeping `web/sites/default` and the shared settings files. Override `platform_backup_output_dir`, `platform_backup_dir`, or `platform_backup_filename` to change paths or file names.
- Use `--tags restore` to extract a tarball back into the platform root while preserving any existing client sites under `web/sites/`. If no archive is provided, the role will pick the latest backup under `/home/<platform_user>/backup/<platform_id>/`. You can still override with `-e "platform_restore_archive=/path/to/file"` or a per-platform mapping in `platform_restore_archives`.
- Run `--tags verify` whenever you need to enforce filesystem ownership. Only the platform verification role triggers the `Enforce Drupal platform ownership` handler, ensuring code matches the Unix user/group defined for the platform.
- Use `--tags clone` to copy a platform's codebase into a new directory (excluding client site directories but keeping `web/sites/default`). Provide the target with `-e "platform_clone_destination=<newname>"`; only the name is accepted (no slashes) and it is placed under `platform_base_dir.path`. The target must differ from the source and not already exist.
- During cloning, if a platform definition file for the new name does not exist under `vars/platforms/`, one is generated from the source definition with the new platform name.

## Extending Roles
- Server roles (`server_install`, `os_ssh`, `os_ufw`, `os_fail2ban`, `server_update`, `server_verify`) should contain OS/package logic only.
- Platform roles handle Drupal codebases (`platform_install`, `platform_update`, `platform_verify`, `platform_delete`, etc.).
- Site roles operate on Drupal site instances (`site_context`, `site_install`, `site_verify`, `site_update`, `site_backup`, `site_restore`, `site_delete`, etc.). The `site_verify` role now owns Apache vhosts, SSL management, login helpers, and permissions hardening, so include it (via `tasks_from` such as `login`, `ssl`, `vhosts`, or `permissions`) whenever those actions are required outside the verification playbook.

Follow the existing patterns: keep templates with their role, add new task files under `tasks/`, and expose handlers where needed so the focused playbooks can orchestrate them cleanly.
