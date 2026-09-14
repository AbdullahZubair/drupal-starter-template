#!/usr/bin/env bash
#
# Shared functions used by the scripts in scripts/. Meant to be sourced,
# never run directly.
set -u
set -o pipefail

# The project's own Drush binary, installed by composer. Every script
# that shells out to Drush uses this same path.
DRUSH="./vendor/bin/drush"

# Ctrl-C during a prompt should look intentional, not like a crash.
trap 'echo; echo "Cancelled."; exit 130' INT
# fail() below signals the running script with TERM so it can stop the
# whole run even when the failure happens inside a subshell.
trap 'exit 1' TERM

fail() {
  # Written to stderr on purpose: this can be called from inside a
  # $(...) subshell, where a plain echo would be captured as data
  # instead of shown on screen.
  echo "Error: $1" >&2
  kill -s TERM "$$" 2>/dev/null
  exit 1
}

run_step() {
  local description="$1"
  shift
  echo "$description"
  "$@" || fail "$description failed."
}

# Asks a yes or no question before doing something destructive.
confirm() {
  local prompt_text="$1" answer
  read -r -p "$prompt_text [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# Strips leading and trailing whitespace, mainly to protect against an
# invisible space left over from a copy and paste.
trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

# Asks a plain text question. A default is shown in brackets and used
# if the answer is left blank, otherwise the question repeats.
prompt() {
  local label="$1" default="${2:-}" value=""
  while true; do
    if [ -n "$default" ]; then
      read -r -p "$label [$default]: " value
    else
      read -r -p "$label: " value
    fi
    value=$(trim "$value")
    value="${value:-$default}"
    [ -n "$value" ] && { printf '%s' "$value"; return; }
    echo "This value is required." >&2
  done
}

# Hidden input, asked twice and compared, since a typo in a password
# you cannot see is otherwise invisible until login fails later.
prompt_password() {
  local label="$1" pass1="" pass2=""
  while true; do
    read -r -s -p "$label: " pass1
    echo >&2
    if [ -z "$pass1" ]; then
      echo "This value is required." >&2
      continue
    fi
    read -r -s -p "Confirm $label: " pass2
    echo >&2
    [ "$pass1" = "$pass2" ] && break
    echo "Those did not match, try again." >&2
  done
  printf '%s' "$pass1"
}

# Confirms .env exists and loads it into the current shell.
require_env_file() {
  [ -f .env ] || fail ".env was not found, run scripts/setup.sh first."
  source .env
}

# Confirms Drush has actually been installed by composer.
require_drush() {
  [ -x "$DRUSH" ] || fail "drush was not found at $DRUSH."
}

# Prefers mariadb since that is what this project actually runs on,
# but falls back to mysql for a host that only has that client.
detect_db_client() {
  local client
  for client in mariadb mysql; do
    command -v "$client" >/dev/null 2>&1 && { echo "$client"; return; }
  done
}

# Maps an already detected query client to its matching dump utility,
# since the two always ship as a pair, mariadb with mariadb-dump,
# mysql with mysqldump. Takes the client detect_db_client already
# found instead of scanning the PATH a second time on its own.
db_dump_client_for() {
  local query_client="$1" dump_client

  case "$query_client" in
    mariadb) dump_client="mariadb-dump" ;;
    mysql) dump_client="mysqldump" ;;
    *) fail "no known dump utility for the database client $query_client." ;;
  esac

  command -v "$dump_client" >/dev/null 2>&1 || fail "$dump_client was not found, even though $query_client is installed."
  echo "$dump_client"
}

# Runs one SQL statement against the given connection and prints its
# output. --batch --skip-column-names keeps the output plain in every
# case, one bare value per line, with nothing to strip.
db_query() {
  local client="$1" host="$2" port="$3" user="$4" password="$5" database="$6" sql="$7" error_message="$8"
  local output

  if ! output=$("$client" --host="$host" --port="$port" --user="$user" --password="$password" \
      --batch --skip-column-names --execute="$sql" "$database" 2>&1); then
    echo "$output"
    fail "$error_message"
  fi

  printf '%s' "$output"
}

# Verifies a database connection actually works, given a client that
# has already been detected, printing its own status line and failing
# with a clear message if the connection does not succeed.
check_db_connection() {
  local client="$1" host="$2" port="$3" user="$4" password="$5" database="$6"
  echo "Checking the database connection with $client..."
  db_query "$client" "$host" "$port" "$user" "$password" "$database" "SELECT 1;" \
    "could not connect to the database with those details, check the credentials and that the database is reachable." >/dev/null
}

# This file lives in <project root>/scripts/, so the project root is
# always exactly one directory above wherever the calling script
# itself lives, regardless of which directory you were standing in
# when you ran it.
cd_to_project_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
  cd "$script_dir/.." || fail "could not change into the project root above $script_dir."
}
