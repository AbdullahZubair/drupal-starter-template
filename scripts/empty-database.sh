#!/usr/bin/env bash
#
# Empties a database by dropping every one of its tables, without
# reinstalling Drupal afterwards. Useful during testing when you want a
# clean database but are not ready to run scripts/setup.sh again. Lives
# in <project root>/scripts/, and works out the project root itself.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Drops every table found in the given database. Shared by both menu
# options so the actual drop logic only exists once.
drop_all_tables() {
  local client="$1" host="$2" port="$3" user="$4" password="$5" database="$6"
  local tables table

  check_db_connection "$client" "$host" "$port" "$user" "$password" "$database"

  # -B (batch) and -N (skip column names) return one plain table name
  # per line, with no header row and no ASCII table borders to strip.
  tables=$(db_query "$client" "$host" "$port" "$user" "$password" "$database" "SHOW TABLES;" \
    "could not list the tables in $database.")

  if [ -z "$tables" ]; then
    echo "No tables found in $database, nothing to do."
    return
  fi

  confirm "This will drop every table in $database. Continue?" || fail "Cancelled."

  while IFS= read -r table; do
    echo "Dropping table $table..."
    db_query "$client" "$host" "$port" "$user" "$password" "$database" "DROP TABLE \`$table\`;" \
      "could not drop table $table." >/dev/null
  done <<< "$tables"

  echo "$database has been emptied successfully."
}

# Option 1: empty the database the current site is already configured
# to use, read through Drush rather than parsed by hand from .env, so
# it stays correct even if the project ever changes how it resolves
# its database connection.
empty_current_site() {
  [ -f .env ] || fail ".env was not found, run this from a project that already has one, or choose manual entry instead."
  require_drush

  confirm "This will drop every table in the current site's database. Continue?" || fail "Cancelled."

  run_step "Dropping all tables using Drush..." "$DRUSH" sql:drop -y
  echo "The database has been emptied successfully."
}

# Option 2: empty an arbitrary database, useful for one that has
# nothing to do with this project at all.
empty_manual_entry() {
  local client host port user password database

  client=$(detect_db_client)
  [ -n "$client" ] || fail "no mysql or mariadb client was found on this machine."

  host=$(prompt "Database host" "localhost")
  port=$(prompt "Database port" "3306")
  database=$(prompt "Database name")
  user=$(prompt "Database user")
  password=$(prompt_password "Database password")

  drop_all_tables "$client" "$host" "$port" "$user" "$password" "$database"
}

main() {
  cd_to_project_root

  echo "How do you want to connect to the database?"
  echo "  1) Use the credentials from .env (the current site)"
  echo "  2) Enter credentials manually"

  local choice
  while true; do
    read -r -p "Choose 1 or 2: " choice
    case "$choice" in
      1) empty_current_site; break ;;
      2) empty_manual_entry; break ;;
      *) echo "Please enter 1 or 2." ;;
    esac
  done
}

main
