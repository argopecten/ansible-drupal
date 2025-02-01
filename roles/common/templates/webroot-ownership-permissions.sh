#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script is used to fix the file and directory ownership and permissions of a Drupal webroot directory.
You need to provide the following argument:

  --web-root: Path to the web root of your Drupal project, obligatory argument.
  --owner: Username of the user to whom you want to give file and directory ownership
                 (defaults to 'ubuntu').
  --owning-group: Owning group to give file and directory ownership (defaults to 'www-data').

Usage: (sudo) ${0##*/} --web-root=PATH --owner=USER --owning-group=GROUP
Example: (sudo) ${0##*/} --web-root=/var/www/drupal-10.4.0 --owner=ubuntu --owning-group=ubuntu
HELP
exit 0
}

# Run only as root
if [ $(id -u) != 0 ]; then
  printf "Error: You must run this with sudo or root.\n"
  exit 1
fi

# Set default values
OWNER="ubuntu"
OWNING_GROUP="www-data"

# Parse command line arguments
for i in "$@"; do
  case $i in
    --web-root=*)
      WEB_ROOT="${i#*=}"
      shift
      ;;
    --owner=*)
      OWNER="${i#*=}"
      shift
      ;;
    --owning-group=*)
      OWNING_GROUP="${i#*=}"
      shift
      ;;
    --help) print_help;;
    *)
      printf "Error: Invalid argument(s), run --help for valid arguments.\n"
      exit 1
  esac
done

# Check if webroot path is provided and is a valid Drupal project
if [ -z "$WEB_ROOT" ]; then
  echo "Error: --web-root argument is required."
  echo "Usage: (sudo) ${0##*/} --web-root=PATH --owner=USER --owning-group=GROUP"
  exit 1
fi
if [ ! -d "${WEB_ROOT}" ] || [ ! -f "${WEB_ROOT}/core/modules/system/system.module" ]; then
  printf "Error: Please provide a valid Drupal webroot directory.\n"
  exit 1
fi

# Check if script user is valid
if [ -z "${OWNER}" ] || [[ $(id -un "${OWNER}" 2> /dev/null) != "${OWNER}" ]]; then
  printf "Error: Please provide a valid user.\n"
  exit 1
fi

cd "${WEB_ROOT}"

printf "Changing ownership inside "${WEB_ROOT}", except /sites directory:\n user => "${OWNER}" \t group => "${OWNING_GROUP}"\n"
# Set the correct ownership for directories and files
find . \( -path "./sites" -prune \) -exec chown "${OWNER}":"${OWNING_GROUP}" '{}' \+
chown "${OWNER}":"${OWNING_GROUP}" ./sites/sites.php

# Set the correct permissions for directories and files
printf "Changing permissions of all directories inside "${WEB_ROOT}", except /sites directory, to "750"...\n"
find . \( -path "./sites" -prune \) -type d -exec chmod 750 '{}' \+

printf "Changing permissions of all files inside "${WEB_ROOT}", except /sites directory, to "640"...\n"
find . \( -path "./sites" -prune \) -type f -exec chmod 640 '{}' \+

echo "Done setting proper ownership and permissions for files and directories of the drupal project."
