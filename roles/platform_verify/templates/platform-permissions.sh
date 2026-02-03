{%- set default_platform_user = platform_default_user | default(ansible_user | default("ubuntu")) -%}
{%- set default_platform_group = platform_default_group | default(default_platform_user) -%}
#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script enforces Drupal platform file and directory permissions (excluding web/sites).
You need to provide the following argument:

  --root: Path to the root of your Drupal platform, obligatory argument.
  --user: Username of the user who owns the code (defaults to '{{ default_platform_user }}').
  --group: Group that owns the code (defaults to '{{ default_platform_group }}').

Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP
Example: (sudo) ${0##*/} --root=/var/www/drupal-11.1.8 --user={{ default_platform_user }} --group={{ default_platform_group }}
HELP
exit 0
}

# Run only as root
if [ "$(id -u)" != 0 ]; then
  printf "Error: You must run this with sudo or root.\n"
  exit 1
fi

# Set default values
USER="{{ default_platform_user }}"
GROUP="{{ default_platform_group }}"

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

# Set permissions for directories and files
code_dir_perms='0750'          # Code directories:    rwxr-x---
code_file_perms='0640'         # Code files:          rw-r-----
vendor_code_other_mask='0007'  # Vendor files:        detect permissions granted to others
vendor_code_other_mode='o-rwx' # Vendor files:        remove permissions for others, do not use numeric mode here!
web_sites_dir_perms='2750'     # web/sites directory: rwxr-s--- (with setgid for group inheritance)
default_site_settings_perm='0440' # web/sites/default settings files

cd "${PLATFORM_ROOT}"

printf "Changing permissions of all directories inside ${PLATFORM_ROOT} (excluding ./web/sites) to ${code_dir_perms} ...\n"
find . -path "./web/sites" -prune -o -type d ! -perm "${code_dir_perms}" -exec chmod "${code_dir_perms}" '{}' \+

printf "Changing permissions of all files inside ${PLATFORM_ROOT} (excluding ./web/sites and vendor) to ${code_file_perms} ...\n"
find . \( -path "./vendor" -o -path "./web/sites" \) -prune -o -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+

printf "Removing other permissions from files inside ${PLATFORM_ROOT}/vendor (mask ${vendor_code_other_mask}) ...\n"
find ./vendor -type f -perm "/${vendor_code_other_mask}" -exec chmod "${vendor_code_other_mode}" '{}' \+

if [ -d "./web/sites" ]; then
  printf "Setting permissions on ./web/sites directory (not contents) to ${web_sites_dir_perms} with setgid for group inheritance...\n"
  chmod "${web_sites_dir_perms}" "./web/sites"
fi

if [ -d "./web/sites/default" ]; then
  printf "Setting permissions on ./web/sites/default and top-level site template files ...\n"
  find ./web/sites/default -type d ! -perm "${code_dir_perms}" -exec chmod "${code_dir_perms}" '{}' \+
  find ./web/sites/default -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+
  find ./web/sites -maxdepth 1 -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+

  SETTINGS_FILES=("settings.php" "settings.local.php" "civicrm.settings.php" "services.yml")
  for file in "${SETTINGS_FILES[@]}"; do
    if [ -f "./web/sites/default/${file}" ]; then
      chmod "${default_site_settings_perm}" "./web/sites/default/${file}"
    fi
  done
fi

echo "Done ensuring permissions for Drupal platform at ${PLATFORM_ROOT}."
