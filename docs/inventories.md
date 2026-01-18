# Inventories

Inventories live under `inventory/` and are split by environment.

```
inventory/
  dev/
    hosts.yml
    group_vars/
      all/main.yml
    host_vars/
      <host>/
        main.yml
        vault.yml
        sites.d/
          <site>.yml
  prod/
    hosts.yml
    group_vars/
      all/main.yml
    host_vars/
      <host>/
        main.yml
        vault.yml
        sites.d/
          <site>.yml
```

## hosts.yml
Each environment defines host groups used by playbooks. Common groups:
- `managed` - targets for `playbooks/server.yml`.
- `lamp` - targets for platform and site playbooks.
- `control` - control nodes (connection local).
- `clientAP`, `clientMH` - customer groupings.
- `lts2404` - OS grouping for Ubuntu 24.04.

Example (prod excerpt):
```yaml
all:
  children:
    managed:
      hosts:
        ap-host01: {}
        mh-host03: {}
    lamp:
      hosts:
        ap-host01: {}
        mh-host03: {}
```

## group_vars
Use group vars for values shared across all hosts in an environment.
- `inventory/<env>/group_vars/all/main.yml` contains shared defaults.
- Additional group vars can be added under `group_vars/<group>/`.

## host_vars
Each host has its own folder with:
- `main.yml` for host metadata and stack selection.
- `vault.yml` for encrypted secrets.
- `sites.d/*.yml` for site definitions.

Example host vars (prod):
```yaml
# inventory/prod/host_vars/mh-host05/main.yml
ansible_host: "{{ vault_mh_host05.ip }}"
stack:
  os: ubuntu-24
  php: php-83
  mysql: mysql-80
  apache: apache-24
  drupal: drupal11.3
platforms:
  drupal11.3:
    user: drupal11_3
    group: drupal11_3
```

## sites.d
Each file under `sites.d/` declares a `sites` mapping keyed by site id.

Example site definition:
```yaml
# inventory/prod/host_vars/mh-host05/sites.d/d1.yml
sites:
  d1:
    name: "{{ vault_mh_host05.d1.name }}"
    platform: "drupal11.3"
    profile: "standard"
    admin_user: "admin"
    modules_enable:
      - syslog
    modules_disable:
      - dblog
    cf:
      zone_id: "{{ vault_mh_host05.d1.cf.zone_id | default('dummy') }}"
      api_key: "{{ vault_mh_host05.d1.cf.api_key | default('dummy') }}"
    state: present
```

## Adding a new host
1. Add the host under `inventory/<env>/hosts.yml` in the correct groups.
2. Create `inventory/<env>/host_vars/<host>/main.yml` and `vault.yml`.
3. Define `stack` and `platforms` for that host.
4. Add any site definitions under `sites.d/`.
