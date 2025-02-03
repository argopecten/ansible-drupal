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
if [ ! -d "${PROJECT_ROOT}/web" ] || [ ! -d "${PROJECT_ROOT}/vendor" ]; then
  printf "Error: Please provide a valid Drupal project directory.\n"
  exit 1
fi

# Check if script user is valid
if [ -z "${USER}" ] || [[ $(id -un "${USER}" 2> /dev/null) != "${USER}" ]]; then
  printf "Error: Please provide a valid user.\n"
  exit 1
fi

cd "${PROJECT_ROOT}"

### Set ownership and permissions for code directories and files
# - scope is /vendor and /web, except /web/sites
# - Code is owned by the drupal user and by its group.
# - Webserver user should be in the drupal users group, so can read and execute
# - Drupal user can write, group only read, other users have no access and permissions.
# - No need for unified permissions in the /vendor folder.

code_dir_perms='u=rwx,g=rx,o=' # Code folders: 0750
code_file_perms='u=rw,g=r,o='  # Code files in /web: 0640
vendor_code_file_perms='o-rwx' # Code files in /vendor: 0**0

# Set ownership for code files and directories
printf "Changing ownership of all contents of ${PROJECT_ROOT}:\n user => ${USER} \t group => ${GROUP}\n"
# works only on files and directories that are not yet owned by the ${USER} and ${GROUP}
# https://stackoverflow.com/questions/4210042/how-do-i-exclude-a-directory-when-using-find
find . -path ./web/sites -prune -o \( ! -user ${USER} -o ! -group ${GROUP} \) \( -type f -o -type d \) -exec chown ${USER}:${GROUP} '{}' \+

# Set permissions for code directories
printf "Changing permissions of all directories inside ${PROJECT_ROOT} to ${code_dir_perms} ...\n"
# find directories that are not having the correct permissions and change them, except the web/sites directory
find . -path "./web/sites" -prune -o -type d ! -perm "${code_dir_perms}" -exec chmod "${code_dir_perms}" '{}' \+
# Set the same permissions for the /web/sites directory
chmod "${code_dir_perms}" ./web/sites

# Set permissions for code files
printf "Changing permissions of all files inside ${PROJECT_ROOT} to ${code_file_perms} ...\n"
# find files that are not having the correct permissions and change them, except the web/sites directory
find . \( -path "./web/sites" -o -path "./vendor" -prune \) -o -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+
find ./vendor -type f ! -perm "${vendor_code_file_perms}" -exec chmod "${vendor_code_file_perms}" '{}' \+

# /web/sites/sites.php file should have 440 permissions
if [ -f ./web/sites/site.php ]; then
  chown "${USER}":"${GROUP}" ./web/sites/sites.php
  find ./web/sites/sites.php -type f -exec chmod 440 '{}' \+
fi

# code inside /web/sites directory
printf "Changing permissions of all files inside ${PROJECT_ROOT}/web/sites/all to ${code_file_perms} ...\n"
if [ -d ./web/sites/all ]; then
  chown "${USER}":"${GROUP}" ./web/sites/all
  find ./web/sites/all \( ! -user ${USER} -o ! -group ${GROUP} \) \( -type f -o -type d \) -print0 | xargs -r -0 -L20 -exec chown ${USER}:${GROUP} '{}' \+
  find ./web/sites/all -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+
fi

echo "Done setting proper ownership and permissions for files and directories of the drupal project."
