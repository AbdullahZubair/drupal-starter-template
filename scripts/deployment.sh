#!/usr/bin/env bash
#
# Deploys new code to one environment: backs up the database, pulls
# the branch matching APP_ENV, installs dependencies, runs database
# and config updates, and rebuilds caches, all behind Drupal's
# maintenance mode so visitors never see a half updated site. Reads
# which environment this is from .env. Lives in <project root>/
# scripts/, and works out the project root itself.
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$SCRIPT_DIR/lib.sh"

main() {
  cd_to_project_root
  require_env_file

  [ -d .git ] || fail "this project is not a git repository."
  require_drush

  run_step "Turning on maintenance mode..." \
    "$DRUSH" state:set system.maintenance_mode 1 --input-format=integer

  # From here on, if any step fails, the script stops immediately and
  # maintenance mode is deliberately left on, since a half finished
  # deploy is exactly the situation where visitors should see a
  # maintenance page rather than a broken site. Turning it back off
  # only happens once, right at the very end, after everything else
  # has already succeeded, and only after the cache has already been
  # rebuilt, so visitors are never let back in before the site is
  # actually ready for them.

  run_step "Backing up the database..." bash "$SCRIPT_DIR/backup-database.sh"

  run_step "Switching to the $APP_ENV branch..." git checkout "$APP_ENV"
  run_step "Pulling the latest code..." git pull

  run_step "Installing dependencies..." composer install --no-interaction --no-dev --optimize-autoloader

  run_step "Running database updates..." "$DRUSH" updatedb -y
  run_step "Importing configuration..." "$DRUSH" config:import -y
  run_step "Rebuilding caches..." "$DRUSH" cache:rebuild

  run_step "Turning off maintenance mode..." \
    "$DRUSH" state:set system.maintenance_mode 0 --input-format=integer

  echo "Deployment to $APP_ENV completed successfully."
}

main
