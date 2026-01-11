{%- set default_site_user = site_default_user | default(platform_default_user) -%}
{%- set default_site_group = site_default_group | default(platform_default_group) -%}
#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script ensures the ownership of a single Drupal site directory (web/sites/<site>).
You need to provide the following argument:

  --root: Path to the root of your Drupal site, obligatory argument.
  --user: Username of the user to whom you want to give ownership
                 (defaults to '{{ default_site_user }}').
  --group: Group of users to give group ownership (defaults to '{{ default_site_group }}').

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

cd "${SITE_ROOT}"

printf "Changing ownership in ${SITE_ROOT} to:\n user => ${USER} \t group => ${GROUP}\n"
find . \( ! -user "${USER}" -o ! -group "${GROUP}" \) -exec chown "${USER}:${GROUP}" '{}' \+

echo "Done ensuring ownership for Drupal site at ${SITE_ROOT}."
