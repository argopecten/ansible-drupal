---
name: supported-lamp
description: Description of supported OS stack components. Use this whan asked to change functionality
---

# Supported OS versions

- Ubuntu 22.04 LTS (Debian family).
- Ubuntu 24.04 LTS (Debian family).

# Supported PHP versions

- PHP 8.3 (Composer 2.9.2).
- PHP 8.4 (Composer 2.9.2).
- Common extensions: fpm, curl, gd, mbstring, mysql, xml, zip, bcmath, intl, soap.

# Webservers

- Apache (apache2 + libapache2-mod-fcgid).
- Modules: headers, ssl, proxy, proxy_fcgi, rewrite, actions, remoteip.
- PHP-FPM (php-fpm; configured for PHP 8.3/8.4).

# Databases

- MySQL 8.0.
- MariaDB 10.6.

# Security components

- openssh-server
- openssh-client
- ufw
- fail2ban
