# Platform Ownership and Permissions Scripts

This directory contains two helpers that standardize Drupal platform filesystem state:

- `platform-ownership.sh`: enforces ownership for everything outside `web/sites`.
- `platform-permissions.sh`: enforces code/vendor permissions outside `web/sites`.

Run them as root/sudo and pass the platform root plus optional platform user/group overrides. Site-specific scripts at `roles/site_verify/templates/site-ownership.sh` and `roles/site_verify/templates/site-permissions.sh` manage everything under `web/sites`.

## Ownership Strategy

- **Platform code (outside `web/sites`)**: owned by the platform user/group supplied at runtime. This keeps the shared codebase writable by the platform operators while preventing the web server from modifying it directly.
- **The `web/sites` directory itself**: owned by platform user/group with setgid bit (`2750`) to ensure new site directories inherit the platform group.
- **Site directories (`web/sites/<site>/`)**: handled exclusively by the site-level scripts. Each site is owned by platform user/group, with Apache accessing via group membership.

## Group Membership Model

The permission system relies on group membership rather than direct ownership:

```
Platform Group (e.g., drupal11)
├── Platform User (primary member)
└── Apache User www-data (added as member)

Files: platform_user:platform_group
Access: Apache reads/writes via group membership
```

Apache is added to each platform group during platform setup. This allows:
- Platform user has full control (owner)
- Apache can read code and write to content directories (group member)
- Other users have no access (no "others" permissions)

## Setgid Bit Strategy

The `web/sites` directory uses the setgid bit (`2750`) to maintain group ownership inheritance:

- When platform operations create new site directories, they automatically inherit the platform group
- Ensures consistent access control without manual intervention
- Apache (as platform group member) can immediately access new sites
- Prevents permission drift as the platform evolves

## Permission Matrix

| Area                                   | Directories | Files | Notes |
|----------------------------------------|-------------|-------|-------|
| Code (core, custom modules, themes…)   | `0750` (rwxr-x---) | `0640` (rw-r-----) | Platform user owns, Apache reads via group membership |
| Vendor (`/vendor`)                     | `0750` (rwxr-x---) | Retain existing, then `o-rwx` | Preserves executable bits while removing "others" access |
| `web/sites` directory                  | `2750` (rwxr-s---) | N/A | Setgid ensures new sites inherit platform group |
| Site-specific paths (`web/sites/<site>/`) | handled by site scripts | handled by site scripts | Run site-level helpers for per-site management |

## Usage Example

```bash
# Set platform ownership and permissions
sudo /usr/local/bin/platform-ownership.sh --root=/var/www/drupal-11.1.8 --user=drupal11 --group=drupal11
sudo /usr/local/bin/platform-permissions.sh --root=/var/www/drupal-11.1.8 --user=drupal11 --group=drupal11

# Then manage individual sites
sudo /usr/local/bin/site-ownership.sh --root=/var/www/drupal-11.1.8/web/sites/example.com --user=drupal11 --group=drupal11
sudo /usr/local/bin/site-permissions.sh --root=/var/www/drupal-11.1.8/web/sites/example.com --user=drupal11 --group=drupal11
```

Refer to each script's inline documentation (`--help`) for detailed usage information.
