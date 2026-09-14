#!/usr/bin/env bash
#
# Takes a manual, point in time backup of the project's database, using
# whichever dump client matches the database client on this machine
# (mariadb with mariadb-dump, or mysql with mysqldump), and reading its
# connection details from .env. Lives in <project root>/scripts/, and
# works out the project root itself.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BACKUP_DIRECTORY="database-exports"

main() {
  cd_to_project_root
  require_env_file

  local query_client dump_client
  query_client=$(detect_db_client)
  [ -n "$query_client" ] || fail "no mysql or mariadb client was found on this machine."
  dump_client=$(db_dump_client_for "$query_client")

  check_db_connection "$query_client" "$DATABASE_HOST" "$DATABASE_PORT" "$DATABASE_USER" "$DATABASE_PASSWORD" "$DATABASE"

  run_step "Clearing caches..." "$DRUSH" cache:rebuild

  local timestamp folder_date file_time backup_dir backup_file
  timestamp=$(date +%d-%m-%Y_%I-%M-%S-%p)
  folder_date="${timestamp%%_*}"
  file_time="${timestamp##*_}"
  file_time="${file_time^^}"
  backup_dir="$BACKUP_DIRECTORY/$folder_date"
  backup_file="$backup_dir/Manual-Backup-$DATABASE-$file_time.sql"

  mkdir -p "$backup_dir" || fail "could not create $backup_dir."

  echo "Backing up $DATABASE to $backup_file..."
  "$dump_client" --host="$DATABASE_HOST" --port="$DATABASE_PORT" --user="$DATABASE_USER" \
    --password="$DATABASE_PASSWORD" "$DATABASE" > "$backup_file" \
    || fail "the database dump failed, check the credentials and that $dump_client is working."

  echo "$DATABASE has been backed up successfully to $backup_file."
}

main
