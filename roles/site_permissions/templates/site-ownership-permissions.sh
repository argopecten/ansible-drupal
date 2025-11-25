#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script is used to fix the file and directory ownership and permissions of a Drupal project.
You need to provide the following argument:

  --root: Path to the root of your Drupal site of a project, obligatory argument.
  --user: Username of the user to whom you want to give file and directory ownership
                 (defaults to 'ubuntu').
  --group: Group of users to give file and directory group ownership (defaults to 'www-data').

Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP
Example: (sudo) ${0##*/} --root=/var/www/drupal-10.4.0/web/sites/example.com --user=ubuntu --group=www-data
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
GROUP="www-data"

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

### Set ownership and permissions for directories and files of a Drupal site
# scope is:
# - code: ./libraries, ./modules, and ./themes directories. No vendor directory!
# - content: ./files and ./private directories
# - settings files: ./settings.php and ./../sites.php
# 
# Ownership
# - Code is owned by the platform user.
# - Groups are set to the webserver group.
# - No permissions for other users.
#
# Permissions:
#   - Code directories:
#     Might exists or not, but if they exist, they should have the following permissions:
#     - directories: 2750 (user can read/write/execute, group can read/execute, others have no access, setgid bit set).
#     - files: 0640 (user can read/write, group can read, others have no access).
#   - Settings files:
#     The settings.php files should have 440 permissions (user can read/write, group can read, others have no access):
#     - settings.php files: 0440 (user can read, group can read, others have no access).
# - Content directories and files:
#   The /web/sites/*/files and /web/sites/*/private directories are used for content storage:
#     - directories: 2770 (user can read/write/execute, group can read/write/execute, others have no access, setgid bit set).
#     - files: 0660 (user can read/write, group can read/write, others have no access).

### Set permissions
# Code directories and files permissions
# - scope is ./libraries, ./modules, and .${SITE_ROOT/themes directories. No vendor directory!
code_dir_perms='u=rwx,g=rx,o='          # Code directories:    0750 or rwxr-x---
code_file_perms='u=rw,g=r,o='           # Code files:          0640 or rw-r-----
# Content directories and files permissions
# - scope is ./files and ./private directories
content_dir_perms="u=rwx,g=rwx,g+s,o="  # Content directories: 2770 or rwxrws---
content_file_perms="ug=rw,o="           # Content files:       0660 or rw-rw----

# Set ownership for code files and directories
printf "Changing ownership in ${SITE_ROOT} to:\n user => ${USER} \t group => ${GROUP}\n"
find . \( -path ./files -o -path ./private -prune \) -o \( ! -user ${USER} -o ! -group ${GROUP} \) \( -type f -o -type d \) -exec chown ${USER}:${GROUP} '{}' \+

# Set permissions for code directories
printf "Changing permissions for code directories inside ${SITE_ROOT} to ${code_dir_perms} ...\n"
# find directories that are not having the correct permissions and change them, except the files and private directories
find . \( -path ./files -o -path ./private -prune \) -o -type d ! -perm "${code_dir_perms}" -exec chmod "${code_dir_perms}" '{}' \+

# Set permissions for code files
printf "Changing permissions for code files inside ${SITE_ROOT} to ${code_file_perms} ...\n"
# find files that are not having the correct permissions and change them, except the files and private directories
find . \( -path ./files -o -path ./private -prune \) -o -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+


### Set ownership and permissions for content directories and files in ./files and ./private directories
printf "Changing permissions for content directories and files in ${SITE_ROOT} ...\n"
# List of content directories to process
DIRECTORIES=("files" "private")
for dir in "${DIRECTORIES[@]}"; do
  if [ -d "./$dir" ]; then
    echo "Processing directory: ./$dir"
    # Set directory permissions (including setgid bit)
    chmod "$content_dir_perms" "./$dir"
    # Process files
    find "./$dir" -type f ! -perm "${content_file_perms}" -exec chmod "${content_file_perms}" '{}' \+
    # Process subdirectories (maintain setgid)
    find "./$dir" -type d ! -perm "${content_dir_perms}" -exec chmod "${content_dir_perms}" '{}' \+
    echo "   Permissions set for ./$dir and its contents"
  else
    echo "   Skipping: ./$dir directory not found."
  fi
done


# settings files should have 440 permissions
find . -type f -name 'settings.php' -exec chmod 440 '{}' \;
find . -type f -name 'settings.local.php' -exec chmod 440 '{}' \;

echo "Done setting proper ownership and permissions for files and directories."
