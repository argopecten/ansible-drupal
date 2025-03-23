# ansible-playbooks
Ansible playbooks for Drupal, Aegir and LAMP provisioning

This repository contains Ansible playbooks for deploying and managing various applications and services.

## Structure

- `vars/group/`: Group-specific variables
- `vars/host/`: Host-specific variables
- `roles/`: Reusable roles with tasks, handlers, files, templates, and variables
- `playbooks/`: Playbooks to execute specific tasks
- `inventory/`: Inventory files defining the hosts and groups
- `ansible.cfg`: Ansible configuration file

## Usage

To run the playbook to deploy Drupal, use the following command:

```sh
ansible-playbook playbooks/deploy_drupal.yml
