<?php

// phpcs:ignoreFile
// The dotenv module loads .env via load.environment.php in composer.json.

// Environment variable helpers.
if (!function_exists('env_var')) {
  function env_var(string $name, mixed $default = NULL): mixed {
    $value = $_ENV[$name] ?? getenv($name);
    return ($value === FALSE || $value === NULL || $value === '') ? $default : $value;
  }
}

// Safely converts common truthy env strings (true, 1, yes, on) to a boolean.
if (!function_exists('env_bool')) {
  function env_bool(string $name, bool $default = FALSE): bool {
    $value = env_var($name);
    return $value === NULL ? $default : in_array(strtolower((string) $value), ['1', 'true', 'yes', 'on'], TRUE);
  }
}

// Throws if a required value is missing; use for secrets with no safe default.
if (!function_exists('env_required')) {
  function env_required(string $name): string {
    $value = env_var($name);
    if ($value === NULL) {
      throw new \RuntimeException("Required environment variable '$name' is not set.");
    }
    return $value;
  }
}

$environment = env_var('APP_ENV', 'production');

/**
 * Database settings.
 *
 * The 'namespace' and 'autoload' keys are only needed for contributed or
 * custom database drivers. Core drivers like mysql don't need them, so
 * they are omitted here.
 */
$databases['default']['default'] = [
  'database' => env_required('DATABASE'),
  'username' => env_required('DATABASE_USER'),
  'password' => env_required('DATABASE_PASSWORD'),
  'host' => env_required('DATABASE_HOST'),
  'port' => env_var('DATABASE_PORT'),
  'prefix' => '',
  'isolation_level' => 'READ COMMITTED',
  'driver' => 'mysql',
];

// Security settings.

// Salt for one time login links, cancel links, form tokens, etc.
$settings['hash_salt'] = env_required('HASH_SALT');

/**
 * Trusted host patterns.
 *
 * Supports a comma separated list of hostnames, for example a domain
 * with and without www. Skips entirely if unset, since an empty pattern
 * would block every request.
 */
$trusted_hosts = array_filter(array_map('trim', explode(',', (string) env_var('TRUSTED_HOST', ''))));
foreach ($trusted_hosts as $host) {
  $settings['trusted_host_patterns'][] = '^' . preg_quote($host) . '$';
  $settings['trusted_host_patterns'][] = '^.+\.' . preg_quote($host) . '$';
}

// Update and maintenance.

// Access control for maintenance scripts (update.php, rebuild.php).
$settings['update_free_access'] = env_bool('UPDATE_FREE_ACCESS');
$settings['rebuild_access'] = env_bool('REBUILD_ACCESS');
$settings['skip_permissions_hardening'] = env_bool('SKIP_PERMISSIONS_HARDENING');

$settings['entity_update_batch_size'] = 50;
$settings['entity_update_backup'] = TRUE;

// Filesystem settings.
// Sync, private, and temp paths must stay outside the public docroot.
$settings['config_sync_directory'] = env_var('CONFIG_SYNC_DIRECTORY');
$settings['file_assets_path'] = env_var('ASSETS_DIRECTORY');
$settings['file_public_path'] = env_var('PUBLIC_FILE_DIRECTORY');
$settings['file_private_path'] = env_var('PRIVATE_FILE_DIRECTORY');
$settings['file_temp_path'] = env_var('TEMPORARY_DIRECTORY');

$settings['file_scan_ignore_directories'] = [
  'node_modules',
  'bower_components',
];

// Configuration overrides.

/**
 * Enable Config Split for the current environment.
 *
 * This only takes effect if the Config Split module is present in the
 * codebase. Settings.php runs before Drupal's module system boots, so there
 * is no reliable way here to confirm the module is actually installed, only
 * that its code exists. That is an acceptable trade-off: if the module is
 * present but not yet installed, this override targets a config object that
 * does not exist yet, which Drupal simply ignores.
 */
if (is_dir($app_root . '/modules/contrib/config_split')) {
  $is_development = $environment === 'development';
  $config['config_split.config_split.development']['status'] = $is_development;
  $config['config_split.config_split.production']['status'] = !$is_development;
}

// Show the environment name in the site name outside of production.
$site_name = env_var('SITE_NAME', 'My Drupal site');
$config['system.site']['name'] = $environment === 'production' ? $site_name : "$site_name ($environment)";

// Form validation.
// Matches the future Drupal 12 default and avoids the status report warning.
$settings['enable_html5_validation'] = FALSE;

// Services.
$settings['container_yamls'][] = $app_root . '/' . $site_path . '/services.yml';

// Load Twig debug settings and the config schema checker in development.
if ($environment === 'development' && file_exists($app_root . '/sites/development.services.yml')) {
  $settings['container_yamls'][] = $app_root . '/sites/development.services.yml';
}

// Migration settings.
$settings['migrate_node_migrate_type_classic'] = FALSE;
