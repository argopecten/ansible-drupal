# Platform Ownership and Permissions Scripts

This directory contains two helpers that standardize Drupal platform filesystem state:

- `platform-ownership.sh`: enforces ownership for everything outside `web/sites`.
- `platform-permissions.sh`: enforces code/vendor permissions outside `web/sites`.

Run them as root/sudo and pass the platform root plus optional platform user/group overrides. Site-specific scripts at `roles/site_verify/templates/site-ownership.sh` and `roles/site_verify/templates/site-permissions.sh` manage everything under `web/sites`.

## Ownership Strategy

- **Platform code (outside `web/sites`)**: owned by the platform user/group supplied at runtime. This keeps the shared codebase writable by the platform operators while preventing the web server from modifying it directly.
- **Site directories (`web/sites/...`)**: handled exclusively by the site-level helper to ensure per-site content and settings follow web-server ownership expectations.

## Permission Matrix

| Area                                   | Directories | Files | Notes |
|----------------------------------------|-------------|-------|-------|
| Code (core, custom modules, themes…)   | `0750` (`u=rwx,g=rx,o=`) | `0640` (`u=rw,g=r,o=`) | Keeps code readable to the group, inaccessible to others. |
| Vendor (`/vendor`)                     | `0750` (same as code) | leave deployed bits, but `chmod o-rwx` to drop access for others | Ensures third‑party code is group readable yet hidden from “others”. |
| Site-specific paths                    | handled by site script | handled by site script | Run the site-level helper to manage files/permissions within `web/sites`. |

Refer to each script’s inline documentation for usage, and pair them with the site helper when you need to manage individual site directories.
