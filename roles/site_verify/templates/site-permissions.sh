{%- set default_site_user = site_default_user | default(ansible_user | default("ubuntu")) -%}
{%- set default_site_group = site_default_group | default(default_site_user) -%}
#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script enforces permissions for a single Drupal site directory (web/sites/<site>).
You need to provide the following argument:

  --root: Path to the root of your Drupal site, obligatory argument.
  --user: Username of the user who owns the site (defaults to '{{ default_site_user }}').
  --group: Group that owns the site (defaults to '{{ default_site_group }}').

Usage: (sudo) ${0##*/} --root=PATH --user=USER --group=GROUP
Example: (sudo) ${0##*/} --root=/var/www/drupal/web/sites/example.com --user={{ default_site_user }} --group={{ default_site_group }}
HELP
exit 0
}

# Run only as root
if [ "$(id -u)" != 0 ]; then
  printf "Error: You must run this with sudo or root.\n"
  exit 1
fi

# Set default values
USER="{{ default_site_user }}"
GROUP="{{ default_site_group }}"

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

# Permission targets
code_dir_perms='0750'       # Code directories inside libraries/modules/themes
code_file_perms='0640'      # Code files
content_dir_perms='2770'    # Content directories (files/private)
content_file_perms='0660'   # Content files (files/private)
settings_perm='0440'        # settings.php/settings.local.php

cd "${SITE_ROOT}"

printf "Changing permissions for code directories inside ${SITE_ROOT} to ${code_dir_perms} ...\n"
find . \( -path "./files" -o -path "./private" \) -prune -o -type d ! -perm "${code_dir_perms}" -exec chmod "${code_dir_perms}" '{}' \+

printf "Changing permissions for code files inside ${SITE_ROOT} to ${code_file_perms} ...\n"
find . \( -path "./files" -o -path "./private" \) -prune -o -type f ! -perm "${code_file_perms}" -exec chmod "${code_file_perms}" '{}' \+

printf "Changing permissions for content directories and files inside ${SITE_ROOT} ...\n"
DIRECTORIES=("files" "private")
for dir in "${DIRECTORIES[@]}"; do
  if [ -d "./$dir" ]; then
    echo "Processing directory: ./$dir"
    chmod "${content_dir_perms}" "./$dir"
    find "./$dir" -type f ! -perm "${content_file_perms}" -exec chmod "${content_file_perms}" '{}' \+
    find "./$dir" -type d ! -perm "${content_dir_perms}" -exec chmod "${content_dir_perms}" '{}' \+
  else
    echo "   Skipping: ./$dir directory not found."
  fi
done

printf "Setting strict permissions on settings files under ${SITE_ROOT} ...\n"
SETTINGS_FILES=("settings.php" "settings.local.php" "civicrm.settings.php" "services.yml")
for file in "${SETTINGS_FILES[@]}"; do
  if [ -f "./$file" ]; then
    echo "   Setting permissions on ./$file"
    chmod "${settings_perm}" "./$file"
  else
    echo "   Skipping: ./$file not found."
  fi
done

echo "Done ensuring permissions for Drupal site at ${SITE_ROOT}."
