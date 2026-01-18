# Documentation

This folder contains the longer-form documentation for the ansible-drupal repo.

## Contents
- `docs/playbooks.md` - what each playbook does, tags, and required CLI vars.
- `docs/roles.md` - role inventory grouped by server/platform/site responsibilities.
- `docs/inventories.md` - inventory layout, host/group vars, and site definitions.
- `docs/variables.md` - variable sources, precedence notes, and key settings.

## Quick start
1. Pick an inventory: `inventory/dev/hosts.yml` or `inventory/prod/hosts.yml`.
2. Limit to a host or group as needed (`-l ap-host01`, `-l clientAP`).
3. Provide required extra vars:
   - `platform` for `playbooks/platform.yml`
   - `site` for `playbooks/site-*.yml`
4. Always include vault credentials when vaults are in use.

Example commands:
```sh
ansible-playbook playbooks/server.yml --tags install -i inventory/dev/hosts.yml
ansible-playbook playbooks/platform.yml --tags install -e "platform=drupal11.3" -l ap-host01 -i inventory/prod/hosts.yml
ansible-playbook playbooks/site-install.yml --tags install -e "site=d1" -l mh-host05 -i inventory/prod/hosts.yml
```
