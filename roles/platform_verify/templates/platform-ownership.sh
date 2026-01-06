{%- set default_platform_user = platform_default_user | default(ansible_user | default("ubuntu")) -%}
{%- set default_platform_group = platform_default_group | default(default_platform_user) -%}
#!/bin/bash

# Help menu
print_help() {
cat <<-HELP
This script ensures the ownership of a Drupal platform codebase (everything outside web/sites).
You need to provide the following argument:

  --root: Path to the root of your Drupal platform, obligatory argument.
  --user: Username of the user to whom you want to give file and directory ownership
                 (defaults to '{{ default_platform_user }}').
  --group: Group of users to give file and directory group ownership (defaults to '{{ default_platform_group }}').

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

cd "${PLATFORM_ROOT}"

printf "Changing ownership in ${PLATFORM_ROOT} (excluding ./web/sites) to:\n user => ${USER} \t group => ${GROUP}\n"
find . -path "./web/sites" -prune -o \
  \( \( -type f -o -type d \) -a \( ! -user "${USER}" -o ! -group "${GROUP}" \) \) \
  -exec chown "${USER}:${GROUP}" '{}' \+

if [ -d "./web/sites" ]; then
  printf "Ensuring ownership of ./web/sites is set to ${USER}:${GROUP} for write access...\n"
  chown -R "${USER}:${GROUP}" "./web/sites"
fi

echo "Done ensuring ownership for Drupal platform at ${PLATFORM_ROOT}."
