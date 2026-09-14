#!/usr/bin/env bash
#
# Sets up a freshly cloned copy of this project: installs dependencies,
# builds a real .env, installs Drupal from the existing configuration,
# and leaves the site ready to use. Assumes the target database already
# exists, this script never creates one. Requires bash. Lives in
# <project root>/scripts/, and works out the project root itself.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

prompt_email() {
  local label="$1" default="$2" value
  while true; do
    value=$(prompt "$label" "$default")
    [[ "$value" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] && { printf '%s' "$value"; return; }
    echo "That does not look like a valid email address." >&2
  done
}

# Reads one fixed value straight out of .env.example, so this script
# and that file can never quietly drift apart. Fails loudly if a key
# is ever missing, rather than writing a broken .env silently.
env_default() {
  local value
  value=$(grep -m1 "^$1=" .env.example | cut -d'=' -f2-)
  [ -n "$value" ] || fail "expected a default value for $1 in .env.example but found none."
  printf '%s' "$value"
}

check_requirements() {
  if [ ! -f composer.json ] || [ ! -f .env.example ]; then
    fail "composer.json or .env.example not found in the project root, make sure this script is still inside a scripts folder directly under the project root."
  fi
  command -v composer >/dev/null 2>&1 || fail "composer is not installed or not on your PATH."
  # CONFIG_SYNC_DIRECTORY is written relative to the web root, one
  # level below the project root, so the leading ../ is dropped here
  # to turn it into a path relative to the project root instead.
  local config_dir
  config_dir=$(env_default CONFIG_SYNC_DIRECTORY)
  config_dir="${config_dir#../}"
  [ -f "$config_dir/core.extension.yml" ] || fail "no exported configuration found in $config_dir, this script installs from existing configuration only."
}

confirm_env_overwrite() {
  [ -f .env ] || return 0
  confirm ".env already exists. Overwrite it and continue?" || { echo "Setup stopped, existing .env left untouched."; exit 0; }
}

collect_environment() {
  local choice
  echo
  echo "Which environment is this?"
  echo "  1) Production"
  echo "  2) Staging"
  echo "  3) Development"
  while true; do
    read -r -p "Choose 1-3: " choice
    case "$choice" in
      1) APP_ENV="production"; return ;;
      2) APP_ENV="staging"; return ;;
      3) APP_ENV="development"; return ;;
      *) echo "Please enter 1, 2, or 3." ;;
    esac
  done
}

collect_database_details() {
  echo
  DATABASE=$(prompt "Database name")
  DATABASE_USER=$(prompt "Database user")
  DATABASE_PASSWORD=$(prompt_password "Database password")
  DATABASE_HOST=$(prompt "Database host")
  # Prompted rather than fixed, since a different host can use a
  # different port, 3306 from .env.example is just the usual default.
  DATABASE_PORT=$(prompt "Database port" "$(env_default DATABASE_PORT)")
  local client
  client=$(detect_db_client)
  if [ -z "$client" ]; then
    echo "No MySQL or MariaDB client found here, skipping the connection check."
    return
  fi
  check_db_connection "$client" "$DATABASE_HOST" "$DATABASE_PORT" "$DATABASE_USER" "$DATABASE_PASSWORD" "$DATABASE"
}

collect_site_details() {
  echo
  while true; do
    TRUSTED_HOST=$(prompt "Trusted host domain (comma separated for more than one)")
    [[ "$TRUSTED_HOST" == *"://"* || "$TRUSTED_HOST" == *"/"* ]] || break
    echo "Enter bare domains only, without http:// or a trailing path, for example example.com" >&2
  done
  SITE_NAME=$(prompt "Site name")
  HASH_SALT=$(head -c 64 /dev/urandom | base64 | tr -d '\n')
}

collect_admin_details() {
  echo
  ADMIN_USER=$(prompt "Admin username" "system")
  ADMIN_EMAIL=$(prompt_email "Admin email" "abdullahzubair2015@gmail.com")
  # Separate from the admin's own email: this is the address Drupal's
  # system emails, password resets included, claim to be sent from.
  SITE_MAIL=$(prompt_email "Site email for system notifications" "$ADMIN_EMAIL")
  ADMIN_PASS=$(prompt_password "Admin password")
}

# Backslash escapes the three characters double quotes treat specially
# in a .env file, so any value, apostrophes included, survives intact.
dotenv_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"
  printf '%s' "$value"
}

write_env_file() {
  {
    printf '# Environment file for the project\n\n'
    printf 'APP_ENV="%s"\n\n' "$(dotenv_escape "$APP_ENV")"
    printf '#Database credentials.\n'
    printf 'DATABASE="%s"\n' "$(dotenv_escape "$DATABASE")"
    printf 'DATABASE_USER="%s"\n' "$(dotenv_escape "$DATABASE_USER")"
    printf 'DATABASE_PASSWORD="%s"\n' "$(dotenv_escape "$DATABASE_PASSWORD")"
    printf 'DATABASE_HOST="%s"\n' "$(dotenv_escape "$DATABASE_HOST")"
    printf 'DATABASE_PORT="%s"\n\n' "$(dotenv_escape "$DATABASE_PORT")"
    printf '# Set the directories for drupal.\n'
    printf 'CONFIG_SYNC_DIRECTORY="%s"\n' "$(dotenv_escape "$(env_default CONFIG_SYNC_DIRECTORY)")"
    printf 'PRIVATE_FILE_DIRECTORY="%s"\n' "$(dotenv_escape "$(env_default PRIVATE_FILE_DIRECTORY)")"
    printf 'PUBLIC_FILE_DIRECTORY="%s"\n' "$(dotenv_escape "$(env_default PUBLIC_FILE_DIRECTORY)")"
    printf 'ASSETS_DIRECTORY="%s"\n' "$(dotenv_escape "$(env_default ASSETS_DIRECTORY)")"
    printf 'TEMPORARY_DIRECTORY="%s"\n\n' "$(dotenv_escape "$(env_default TEMPORARY_DIRECTORY)")"
    printf '#Set the Drupal settings.\n'
    printf 'HASH_SALT="%s"\n' "$(dotenv_escape "$HASH_SALT")"
    printf 'SITE_NAME="%s"\n' "$(dotenv_escape "$SITE_NAME")"
    printf 'SKIP_PERMISSIONS_HARDENING="%s"\n' "$(dotenv_escape "$(env_default SKIP_PERMISSIONS_HARDENING)")"
    printf 'UPDATE_FREE_ACCESS="%s"\n' "$(dotenv_escape "$(env_default UPDATE_FREE_ACCESS)")"
    printf 'REBUILD_ACCESS="%s"\n' "$(dotenv_escape "$(env_default REBUILD_ACCESS)")"
    printf 'TRUSTED_HOST="%s"\n\n' "$(dotenv_escape "$TRUSTED_HOST")"
    printf '#End.\n'
  } > .env
  echo ".env created."
}

install_drupal() {
  run_step "Installing Drupal from the existing configuration..." \
    "$DRUSH" site:install --existing-config \
    --account-name="$ADMIN_USER" \
    --account-pass="$ADMIN_PASS" \
    --account-mail="$ADMIN_EMAIL" \
    -y
  run_step "Assigning the Administrator role..." \
    "$DRUSH" user:role:add administrator "$ADMIN_USER"
  run_step "Importing configuration..." \
    "$DRUSH" config:import -y
  run_step "Setting the site name..." \
    "$DRUSH" config:set system.site name "$SITE_NAME" -y
  run_step "Setting the site email..." \
    "$DRUSH" config:set system.site mail "$SITE_MAIL" -y
  run_step "Rebuilding caches..." \
    "$DRUSH" cache:rebuild
  echo "Caching environment variables..."
  "$DRUSH" dotenv:dump || echo "Warning: drush dotenv:dump did not complete. The site is installed and working, run it manually when convenient."
}

main() {
  cd_to_project_root
  check_requirements
  confirm_env_overwrite
  run_step "Installing dependencies..." composer install --no-interaction
  require_drush
  collect_environment
  collect_database_details
  collect_site_details
  write_env_file
  collect_admin_details
  install_drupal
  echo
  echo "Setup complete. You can now sign in with the username: $ADMIN_USER"
}

main
