# ansible-drupal
Infrastructure-as-code for building and running Drupal platforms on Ubuntu hosts.

## Repository Layout
- `inventory/` – per-environment directories (e.g. `clientAP-dev/`, `clientMH-prod/`, `control/`) with their own `hosts.ini`, `group_vars/`, `host_vars/`, and `vault.yml`.
- `playbooks/` – task-specific entry points: `server.yml`, `platform-install.yml`, `platform-update.yml`, `platform-verify.yml`, `platform-delete.yml`, `site-install.yml`, `site-update.yml`, `site-verify.yml`, `site-backup.yml`, `site-restore.yml`, `site-delete.yml`, and the legacy aggregators (`servers.yml`, `platforms.yml`, `sites.yml`).
- `roles/` – decomposed roles for each lifecycle stage (server\_\*, apache, mysql, php, platform\_\*, site\_\*, etc.). Shared templates/handlers now live with their owning role.
- `ansible.cfg` – default Ansible settings (inventory, roles path, user, etc.).
- `LICENSE` and `README.md`.

## Choosing an Inventory
Each client/environment lives inside `inventory/<name>/`. Example:
```
inventory/
  clientAP-dev/
    hosts.ini
    group_vars/all.yml
    host_vars/ap-host01-dev.yml
    vault.yml
```
Select the desired inventory via `-i inventory/<name>/hosts.ini` or override the default in `ansible.cfg`.

## Running Playbooks
Common examples (always include `--ask-vault-pass` or `--vault-password-file` when secrets are stored in the vault):
```sh
# Harden/patch servers
ansible-playbook playbooks/server.yml --tags "install,secure" -i inventory/clientAP-dev/hosts.ini

# Provision or update Drupal codebases
ansible-playbook playbooks/platform-install.yml --tags install -e "platform=d11_standard" -i inventory/clientAP-dev/hosts.ini
ansible-playbook playbooks/platform-update.yml --tags update -i inventory/clientAP-dev/hosts.ini

# Manage Drupal sites
ansible-playbook playbooks/site-install.yml --tags install -e "site=client1-main" -i inventory/clientAP-dev/hosts.ini
ansible-playbook playbooks/site-update.yml --tags update -i inventory/clientAP-dev/hosts.ini
ansible-playbook playbooks/site-backup.yml --tags backup -e "site=client1-main" -i inventory/clientAP-dev/hosts.ini
```

## Extending Roles
- Server roles (`server_base`, `server_security`, `server_update`, `server_verify`) should contain OS/package logic only.
- Platform roles handle Drupal codebases (`platform_base`, `platform_install`, `platform_update`, `platform_verify`, `platform_delete`, `platform_permissions`, etc.).
- Site roles operate on Drupal site instances (`site_base`, `site_install`, `site_settings`, `site_permissions`, `site_vhost`, `site_update`, `site_backup`, `site_restore`, `site_delete`, etc.).

Follow the existing patterns: keep templates with their role, add new task files under `tasks/`, and expose handlers where needed so the focused playbooks can orchestrate them cleanly.
