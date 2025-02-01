#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script is used to fix the file and directory ownership and permissions of a Drupal project.
You need to provide the following argument:

  --root: Path to the root of your Drupal project, obligatory argument.
  --user: Username of the user to whom you want to give file and directory ownership
                 (defaults to 'ubuntu').
  --group: Group of users to give file and directory group ownership (defaults to 'ubuntu').

Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP
Example: (sudo) ${0##*/} --root=/var/www/drupal-10.4.0 --user=ubuntu --group=ubuntu
HELP
exit 0
}

# Run only as root
if [ $(id -u) != 0 ]; then
  printf "Error: You must run this with sudo or root.\n"
  exit 1
fi

# Set default values
USER="ubuntu"
GROUP="ubuntu"

# Parse command line arguments
for i in "$@"; do
  case $i in
    --root=*)
      PROJECT_ROOT="${i#*=}"
      shift
      ;;
    --user=*)
      USER="${i#*=}"
      shift
      ;;
    --group=*)
      GROUP="${i#*=}"
      shift
      ;;
    --help) print_help;;
    *)
      printf "Error: Invalid argument(s), run --help for valid arguments.\n"
      exit 1
  esac
done

# Check if root path is provided and is a valid Drupal project
if [ -z "$PROJECT_ROOT" ]; then
  echo "Error: --root argument is required."
  echo "Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP"
  exit 1
fi
if [ ! -d "${PROJECT_ROOT}/web" ] && [ ! -d "${PROJECT_ROOT}/vendor" ]; then
  printf "Error: Please provide a valid Drupal project directory.\n"
  exit 1
fi

# Check if script user is valid
if [ -z "${USER}" ] || [[ $(id -un "${USER}" 2> /dev/null) != "${USER}" ]]; then
  printf "Error: Please provide a valid user.\n"
  exit 1
fi

cd "${PROJECT_ROOT}"

printf "Changing ownership of all contents of "${PROJECT_ROOT}":\n user => "${USER}" \t group => "${GROUP}"\n"
# list only files and directories that are not owned by the user and group
find ./web \( ! -user ${USER} -o ! -group ${GROUP} \) \( -type f -o -type d \) -print0 | xargs -r -0 -L20 ls -la


find . \( -path "./sites" -prune \) -exec chown ${USER}:${GROUP} '{}' \+


printf "Changing ownership inside "${WEB_ROOT}", except /sites directory:\n user => "${USER}" \t group => "${GROUP}"\n"
# Set the correct ownership for directories and files
# find . \( -path "./sites" -prune \) -exec chown "${USER}":"${GROUP}" '{}' \+
# https://stackoverflow.com/questions/4210042/how-do-i-exclude-a-directory-when-using-find
find ./web -not -path "./sites/*" -exec chown "${USER}":"${GROUP}" '{}' \+

# Set the correct permissions for directories and files
printf "Changing permissions of all directories inside "${WEB_ROOT}", except /sites directory, to "750"...\n"
find . \( -path "./sites" -prune \) -type d -exec chmod 750 '{}' \+

printf "Changing permissions of all files inside "${WEB_ROOT}", except /sites directory, to "640"...\n"
find . \( -path "./sites" -prune \) -type f -exec chmod 640 '{}' \+

# site/sites.php file should have 440 permissions
if [ -f ./sites/site.php ]; then
  chown "${USER}":"${GROUP}" ./sites/sites.php
  find ./sites/site.php -type f -exec chmod 440 '{}' \+
fi

# list only files and directories that are not owned by the user and group
find ./web \( ! -user ${USER} -o ! -group ${GROUP} \) \( -type f -o -type d \) -print0 | xargs -r -0 -L20 ls -la

# list only files and directories that are not having the correct permissions
find ./web -type d ! -perm $3 -print0 | xargs -r -0 -L20 chmod $3
find ./web -type d ! -perm "u=rwx,g=rwxs,o=" -print0 | xargs -r -0 -L20 ls -la

find ./web -type d \( -path /sites/\*/files -prune \) -print0 | xargs -r -0 -L20 ls -la
find ./web \( -path ./web/sites/\*/files -prune \) -o \( -type $2 ! -perm $3 -print0 \) | xargs -r -0 -L4 chmod $3
find web -type d \( -path web/core -prune \) -o -print0 | xargs -r -0 -L20 ls -la
find web -type d \( -path web/core -prune \) -o ! -perm "u=rwx,g=rwxs,o=" -print0 | xargs -r -0 -L20 ls -la


# TBD: sites/all
# chown -R ${USER}:${GROUP} ./sites/all

echo "Done setting proper ownership and permissions for files and directories of the drupal project."
