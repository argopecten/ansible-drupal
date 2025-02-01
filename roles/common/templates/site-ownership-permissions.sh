#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script is used to fix the file and directory ownership and permissions of a Drupal site within a webroot.
You need to provide the following argument:

  --root: Path to the root of your Drupal project, obligatory argument.
  --script-user: Username of the user to whom you want to give file ownership
                 (defaults to 'ubuntu').
  --web-group: Web server group name (defaults to 'www-data').

Usage: (sudo) ${0##*/} --root=PATH --script-user=USER --web_group=GROUP
Example: (sudo) ${0##*/} --root=/var/www/drupal-10.4.0 --script-user=aegir --web-group=www-data
HELP
exit 0
}

# Run only as root
if [ $(id -u) != 0 ]; then
  printf "Error: You must run this with sudo or root.\n"
  exit 1
fi

# Set default values
SCRIPT_USER="ubuntu"
WEB_GROUP="www-data"

# Parse command line arguments
for i in "$@"; do
  case $i in
    --root=*)
      ROOT="${i#*=}"
      shift
      ;;
    --script-user=*)
      SCRIPT_USER="${i#*=}"
      shift
      ;;
    --web-group=*)
      WEB_GROUP="${i#*=}"
      shift
      ;;
    --help) print_help;;
    *)
      printf "Error: Invalid argument(s), run --help for valid arguments.\n"
      exit 1
  esac
done

# Check if root path is provided
if [ -z "$ROOT" ]; then
  echo "Error: --root argument is required."
  echo "Usage: (sudo) ${0##*/} --root=PATH --script-user=USER --web-group=GROUP"
  exit 1
fi
