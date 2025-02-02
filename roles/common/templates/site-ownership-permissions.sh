#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script is used to fix the file and directory ownership and permissions of a Drupal project.
You need to provide the following argument:

  --root: Path to the root of your Drupal site of a project, obligatory argument.
  --user: Username of the user to whom you want to give file and directory ownership
                 (defaults to 'ubuntu').
  --group: Group of users to give file and directory group ownership (defaults to 'ubuntu').

Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP
Example: (sudo) ${0##*/} --root=/var/www/drupal-10.4.0/web/sites/example.com --user=ubuntu --group=ubuntu
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
      SITE_ROOT="${i#*=}"
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

# Check if root path is provided and is a valid Drupal site
if [ -z "$SITE_ROOT" ]; then
  echo "Error: --root argument is required."
  echo "Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP"
  exit 1
fi
if [ ! -d "${SITE_ROOT}/files" ] || [ ! -f "${SITE_ROOT}/settings.php" ]; then
  printf "Error: Please provide a valid Drupal site directory.\n"
  exit 1
fi

# Check if script user is valid
if [ -z "${USER}" ] || [[ $(id -un "${USER}" 2> /dev/null) != "${USER}" ]]; then
  printf "Error: Please provide a valid user.\n"
  exit 1
fi

cd "${SITE_ROOT}"

### Set ownership and permissions for code directories and files
# - scope is ./libraries, ./modules, ./themes, and ./vendor directories
# - special care is needed for the settings.php files
# - Code is owned by the drupal user and by its group.
# - Drupal user can write, group only read, other users have no access and permissions.
# - Webserver user should be in the drupal users group, so can read and execute
# - No need for unified permissions in the /vendor folder.

code_dir_perms='u=rwx,g=rxs,o=' # Code folders: 2750
code_file_perms='u=rw,g=r,o='  # Code files in /web: 0640
vendor_code_file_perms='o-rwx' # Code files in /vendor: 0**0

# Set ownership for code files and directories
printf "Changing ownership of all contents of ${SITE_ROOT}:\n user => ${USER} \t group => ${GROUP}\n"
# works only on files and directories that are not yet owned by the ${USER} and ${GROUP}
# https://stackoverflow.com/questions/4210042/how-do-i-exclude-a-directory-when-using-find
find . \( ! -user ${USER} -o ! -group ${GROUP} \) \( -type f -o -type d \) -exec chown ${USER}:${GROUP} '{}' \+

# Set permissions for code directories
printf "Changing permissions of all directories inside ${SITE_ROOT} to ${code_dir_perms} ...\n"
# find directories that are not having the correct permissions and change them, except the web/sites directory
find . \( -path ./files -o -path ./private -prune \) -o -type d ! -perm "${code_dir_perms}" -exec chmod "${code_dir_perms}" '{}' \+

# Set permissions for code files
printf "Changing permissions of all files inside ${SITE_ROOT} to ${code_file_perms} ...\n"
# find files that are not having the correct permissions and change them, except the web/sites directory
find . -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+
find ./vendor -type f ! -perm "${vendor_code_file_perms}" -exec chmod "${vendor_code_file_perms}" '{}' \+

# settings files should have 440 permissions
if [ -f ./settings.php ]; then
  chown "${USER}":"${GROUP}" ./settings.php
  find . -type f -name '*settings.php' -exec chmod 440 '{}' \;
fi

### Set ownership and permissions for content directories and files
# - scope is ./files and ./private directories
# - Code is owned by the drupal user and by its group.
# - Drupal user and group can write, other users have no access and permissions.
# - Webserver user should be in the drupal users group, so can read, write and execute
# - TBD: sticky bit for group permissions!
# - TBC: js and css directories in the files directory

# Content folders 	u=rwx,g=rwx,o= 	2770 	rwxrwx---
# Content files 	ug=rw,o= 	0660 	rw-rw----
content_dir_perms="u=rwx,g=rws,o="
content_file_perms='ug=rw,o='

# Set permissions for content directories
printf "Changing permissions for ./files and ./private directories inside ${SITE_ROOT} to ${content_file_perms} ...\n"
find ./files   -type d ! -perm "${content_dir_perms}" -exec chmod "${content_dir_perms}" '{}' \+
find ./private -type d ! -perm "${content_dir_perms}" -exec chmod "${content_dir_perms}" '{}' \+

# Set permissions for content files
find ./files -type f ! -perm "${content_file_perms}" -exec chmod "${content_file_perms}" '{}' \+
find ./private -type f ! -perm "${content_file_perms}" -exec chmod "${content_file_perms}" '{}' \+

echo "Done setting proper ownership and permissions for files and directories of a drupal site."
