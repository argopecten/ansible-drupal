# Roles

Roles are organized by responsibility. Keep templates and handlers with the
owning role.

## Server roles (OS and security)
- `server_install` - base OS packages and prerequisites.
- `server_secure` - security hardening (SSH/ufw/fail2ban integration).
- `server_update` - package updates and maintenance.
- `server_verify` - validation checks for server state.

## OS component roles
- `os_apache` - Apache install/config, vhosts templates, error pages.
- `os_mysql` - MySQL or MariaDB installation and config.
- `os_php` - PHP-FPM setup, extensions, and overrides.
- `os_ssh` - SSHD configuration and hardening templates.
- `os_ufw` - firewall defaults and rules.
- `os_fail2ban` - fail2ban configuration and jails.
- `os_cloudflare` - Cloudflare integration helpers.

## Platform roles (Drupal codebase)
- `platform_context` - resolves platform selection and merges vars.
- `platform_install` - provisioning Drupal codebases via Composer.
- `platform_update` - updates for existing platforms.
- `platform_verify` - permissions and health checks.
- `platform_backup` - codebase backups.
- `platform_restore` - restore from backups.
- `platform_clone` - clone platform codebases.
- `platform_delete` - remove platform resources.

## Site roles (Drupal instance)
- `site_context` - resolves site selection and platform paths.
- `site_install` - site provisioning, initial modules, settings.
- `site_update` - updates and config imports.
- `site_verify` - vhosts, SSL, permissions, login helpers.
- `site_backup` - DB + files backup.
- `site_restore` - restore DB + files.
- `site_migrate` - migrate site to another platform.
- `site_login` - generate login URLs.
- `site_delete` - delete site resources.

## Defaults and handlers
- Defaults live under `roles/<role>/defaults/main.yml`.
- Handlers live under `roles/<role>/handlers/main.yml`.
- Templates live under `roles/<role>/templates/`.

If you add or extend a role, keep it single-purpose and referenced via the
playbooks so tag-based execution stays predictable.
