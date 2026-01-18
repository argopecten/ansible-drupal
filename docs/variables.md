# Variables

Variables come from several layers. The common sources used by playbooks are
listed below.

## Precedence and sources
Approximate order (lowest to highest):
1. Role defaults: `roles/<role>/defaults/main.yml`
2. Stack and environment vars loaded by playbooks:
   - `vars/environments/<env>.yml`
   - `vars/stack/os/<stack.os>.yml`
   - `vars/stack/php/<stack.php>.yml`
   - `vars/stack/mysql/<stack.mysql>.yml`
   - `vars/stack/apache/<stack.apache>.yml`
   - `vars/stack/security/*.yml` (server and site playbooks)
   - `vars/platforms/platform.yml` and `vars/platforms/<platform>.yml` (platform playbook)
3. Inventory group vars: `inventory/<env>/group_vars/`
4. Inventory host vars: `inventory/<env>/host_vars/<host>/main.yml`
5. Vault files: `inventory/<env>/host_vars/<host>/vault.yml` and
   `inventory/<env>/group_vars/<group>/vault.yml`
6. Extra vars: `-e "key=value"` on the CLI

## Inventory-level variables
Common patterns you will see in `host_vars/<host>/main.yml`:
- `env`: environment key used for `vars/environments/<env>.yml`.
- `client_name`: friendly client or account label.
- `stack`: selects stack component files (os/php/mysql/apache/drupal).
- `platforms`: map of platform IDs to Unix user/group ownership.
- `cloudflare_enabled`, `host_secured`, `data_volume_root`: host settings.
- `apache_catch_all_cf`, `apache_catch_all_ssl`: default SSL settings.

Site variables under `sites.d/*.yml` are keyed by site id:
- `name`: public FQDN for the site.
- `platform`: platform id to host the site.
- `profile`: Drupal profile name.
- `admin_user`: admin username.
- `modules_enable` / `modules_disable`: module lists on install.
- `cf`: Cloudflare settings for SSL automation.
- `state`: desired state (`present` or `absent`).

## Stack variables
Stack variables describe the OS and service versions in use.

Examples:
- `vars/stack/php/php-83.yml`
  - `php_version`, `php_extensions`, `php_fpm_*` settings
  - `composer_version`, `composer_project_options`
- `vars/stack/apache/apache-24.yml`
  - `apache_packages`, `apache_required_modules`, `apache_log_level`
- `vars/stack/mysql/mysql-80.yml` and `vars/stack/mysql/mariadb-106.yml`
  - MySQL/MariaDB packages, paths, and tunables
- `vars/stack/security/ssl.yml`
  - `ssl_selfsigned_*`, `ssl_cf_*` parameters
- `vars/stack/security/cloudflare.yml`
  - `cloudflare_ipv4_cidrs`, `cloudflare_ipv6_cidrs` (generated)

## Environment variables
`vars/environments/<env>.yml` controls per-environment defaults like
`php_fpm_log_level` and fail2ban settings (`fail2ban_*`).

## Platform variables
Platform definitions live under `vars/platforms/` and are merged with the host
`platforms` mapping.

Key fields from platform definitions typically include:
- `platform_id` or file name (used as the platform key)
- Composer project settings (core, profile, version)
- Paths like `platform_base_dir` and ownership overrides

## Playbook-scoped variables
These variables are required or commonly used at runtime:
- `platform` (required for `playbooks/platform.yml`)
- `site` (required for `playbooks/site-*.yml`)
- `platform_restore_archive` / `platform_restore_archives`
- `platform_clone_destination`
- `site_restore_timestamp`
- `site_migrate_target_platform` (or `site_target_platform`)

If you add a new variable, document it in the relevant role defaults and update
this file with the source and expected usage.
