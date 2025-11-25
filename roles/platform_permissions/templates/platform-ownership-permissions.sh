#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script is used to fix the file and directory ownership and permissions of a Drupal platform.
You need to provide the following argument:

  --root: Path to the root of your Drupal platform, obligatory argument.
  --user: Username of the user to whom you want to give file and directory ownership
                 (defaults to 'ubuntu').
  --group: Group of users to give file and directory group ownership (defaults to 'ubuntu').

Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP
Example: (sudo) ${0##*/} --root=/var/www/drupal-11.1.8 --user=ubuntu --group=ubuntu
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
WEBGROUP="www-data"

# Parse command line arguments
for i in "$@"; do
  case $i in
    --root=*)
      PLATFORM_ROOT="${i#*=}"
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
if [ -z "$PLATFORM_ROOT" ]; then
  echo "Error: --root argument is required."
  echo "Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP"
  exit 1
fi
if [ ! -d "${PLATFORM_ROOT}/web" ] || [ ! -d "${PLATFORM_ROOT}/vendor" ]; then
  printf "Error: Please provide a valid Drupal project directory.\n"
  exit 1
fi

# Check if script user is valid
if [ -z "${USER}" ] || [[ $(id -un "${USER}" 2> /dev/null) != "${USER}" ]]; then
  printf "Error: Please provide a valid user.\n"
  exit 1
fi

cd "${PLATFORM_ROOT}"

### Set ownership and permissions for Drupal platform directories and files
# - Ownership:
#   - default is files and dirs are owned by the platform user and by its group.
#   - Webserver group (www-data) ownership is set for the document root (the /web directory).
# - Permissions:
#   - Code directories and files:
#     - directories: 0750 (user can read/write/execute, group can read/execute, others have no access).
#     - files: 0640 (user can read/write, group can read, others have no access).
#   - Vendor code and recipes:
#     The /vendor directory is used for third-party libraries, so it has different file permissions.
#     - directories: 0750 (user can read/write/execute, group can read/execute, others have no access).
#     - files: leave as deployed, just revoke all permissions for others.
#   - Content directories and files:
#     The /web/sites/*/files and /web/sites/*/private directories are used for content storage:
#     - directories: 2770 (user can read/write/execute, group can read/write/execute, others have no access, setgid bit set).
#     - files: 0660 (user can read/write, group can read/write, others have no access).
#   - Settings files:
#     The settings.php files are critical for the Drupal platform and should have restricted permissions:
#     - settings.php files: 0440 (user can read, group can read, others have no access).
#     - settings.local.php files: 0440 (user can read, group can read, others have no access).
#     - sites.php files: 0440 (user can read, group can read, others have no access).

# Set permissions for directories and files
code_dir_perms='u=rwx,g=rx,o='          # Code directories:    0750 or rwxr-x---
code_file_perms='u=rw,g=r,o='           # Code files:          0640 or rw-r-----
vendor_code_file_perms='o-rwx'          # Vendor files:        0**0 or (revoke permissions for others)
content_dir_perms="u=rwx,g=rwx,g+s,o="  # Content directories: 2770 or rwxrws---
content_file_perms="ug=rw,o="           # Content files:       0660 or rw-rw----


### Code files and directories
# https://stackoverflow.com/questions/4210042/how-do-i-exclude-a-directory-when-using-find
printf "Changing ownership in ${PLATFORM_ROOT} to:\n user => ${USER} \t group => ${GROUP}\n"
find . \( -path "./web" \) -prune -o \( ! -user ${USER} -o ! -group ${GROUP} \) \( -type f -o -type d \) -exec chown ${USER}:${GROUP} '{}' \+

# Set permissions for code directories
printf "Changing permissions of all directories inside ${PLATFORM_ROOT} to ${code_dir_perms} ...\n"
find . \( -path "./web/sites/*/files" -o -path "./web/sites/*/private" \) -prune -o -type d ! -perm "${code_dir_perms}" -exec chmod "${code_dir_perms}" '{}' \+
# Set permissions for code files
printf "Changing permissions of all files inside ${PLATFORM_ROOT} to ${code_file_perms} ...\n"
find . \( -path "./vendor" -o -path "./web/sites/*/files" -o -path "./web/sites/*/private" \) -prune -o -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+
# Set permissions for vendor code files
printf "Changing permissions of all files inside ${PLATFORM_ROOT}/vendor to ${vendor_code_file_perms} ...\n"
find ./vendor -type f ! -perm "${vendor_code_file_perms}" -exec chmod "${vendor_code_file_perms}" '{}' \+


### Content directories and files
# Set ownership for content files and directories
printf "Changing ownership in ${PLATFORM_ROOT}/web to:\n user => ${USER} \t group => ${WEBGROUP}\n"
find ./web \( ! -user ${USER} -o ! -group ${WEBGROUP} \) \( -type f -o -type d \) -exec chown ${USER}:${WEBGROUP} '{}' \+

# Set permissions for content directories
printf "Changing permissions of all directories inside ${PLATFORM_ROOT}/web/sites/*/files to ${content_dir_perms} ...\n"
# List of content directories to process
DIRECTORIES=("files" "private")
# Process each site directory
for D in "${PLATFORM_ROOT}/web/sites/"*/ ; do
  [ -d "$D" ] && echo "Found subdirectory: $D"
  # Process each content directory within the site directory
  for dir in "${DIRECTORIES[@]}"; do
    if [ -d "${D%/}/$dir" ]; then
      echo "Processing directory: ${D%/}/$dir"
      # Set directory permissions (including setgid bit)
      chmod "$content_dir_perms" "${D%/}/$dir"
      # Process files
      find "${D%/}/$dir" -type f ! -perm "${content_file_perms}" -exec chmod "${content_file_perms}" '{}' \+
      # Process subdirectories (maintain setgid)
      find "${D%/}/$dir" -type d ! -perm "${content_dir_perms}" -exec chmod "${content_dir_perms}" '{}' \+
      echo "   Permissions set for ${D%/}/$dir and its contents"
    else
      echo "   Skipping: ${D%/}/$dir directory not found."
    fi
  done
  echo "Done processing $D"
done


### settings files should have 440 permissions
# Set permissions for settings files for all sites
find ./web/sites/* -type f -name 'settings.php' -exec chmod 440 '{}' \;
find ./web/sites/* -type f -name 'settings.local.php' -exec chmod 440 '{}' \;
# Set permissions for the sites.php files
find ./web/sites/* -type f -name 'sites.php' -exec chmod 440 '{}' \;


echo "Done setting proper ownership and permissions for files and directories of the drupal platform."
