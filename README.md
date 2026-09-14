# Drupal Starter Template

A reusable Drupal starting point for developers who would rather build the next site than copy the same setup files from the last one and hope nothing breaks.

The template will be updated whenever I feel it needs new improvements, better defaults, or changes required by newer Drupal releases.

## Why I created this

Starting a Drupal project often means repeating the same preparation work: environment variables, `settings.php`, configuration folders, development settings, deployment helpers, database backups, and a few small improvements that every project seems to need.

I built this template to put that foundation in one place. Clone it, configure it, and start working on the site itself.

## Features

- Minimal Drupal installation with no sample content, custom content types, fields, or project-specific features.
- Based on Drupal’s `drupal/recommended-project` template, using `web` as the public document root and keeping the project files separate from publicly served files.
- Drupal’s new default admin theme enabled from the start.
- Interactive setup that collects the new project’s environment, database, domain, site, and administrator details.
- Uses an existing database and does not create one; the selected database must be disposable because Drupal empties it during setup.
- `.env` support for database credentials, hash salt, trusted hosts, site details, and environment-specific values.
- Optional direnv support that adds `vendor/bin` to the command path, allowing Drush to be run directly as `drush`.
- Secrets kept outside committed Drupal configuration and excluded from Git.
- Environment-aware settings for development, staging, and production.
- Automatic environment indicator in the site name for non-production environments, while production keeps the clean site name.
- Development configuration with Twig debugging, automatic template reloading, disabled Twig cache, and configuration schema checks.
- Production configuration with page caching and CSS and JavaScript preprocessing enabled.
- Staging treated as production so it can accurately mirror the live site.
- Config Split for keeping development and production configuration separate from shared configuration.
- Public files stored in `web/files`, giving them simple URLs such as `/files/...` instead of Drupal’s default `/sites/default/files/...` path.
- Front-end assets stored in `web/assets` instead of using the default assets location.
- Private files, temporary files, and configuration stored outside the public `web` directory.
- Environment-based trusted host patterns and security settings in `settings.php`.
- Argon2id password hashing enabled as a stronger modern default.
- HTML5 form validation disabled to follow Drupal’s upcoming default behavior.
- Deployment flow with maintenance mode, database backup, code update, dependency installation, database updates, configuration import, and cache rebuild.
- Manual database backup support with dated backup folders and filenames.
- Confirmed database cleanup for development and testing.
- Coffee for faster administration-area navigation.
- Custom Coffee Shortcut module for changing Coffee’s shortcut or freeing `Alt + D` for the browser.
- Custom Experimental Theme Status module for hiding the warning when an experimental theme has been deliberately selected.
- Custom modules installed through Composer VCS repositories, so they are available to every project without manual copying.

## How to use it

Clone the template into a new project, create an empty database for it, and run the setup script. Enter the requested details and Drupal will install the site from the template’s existing configuration.

The setup asks for the new site name, site email, administrator account, domain, and database details, so the installed site is configured for the project from the beginning. After that, add the content types, fields, themes, modules, and features the project needs.

This template does not try to decide what every Drupal site should contain. It provides the groundwork and leaves the actual site to you.

## Development workflow

Build and test the site in development, where debugging features make changes easier to work with. When a release is ready, deploy it to staging and test it as a production mirror. Once it is verified, deploy the same work to production.

Development is intentionally different from the other environments. Staging and production use the same production configuration so staging can reveal the problems that development settings sometimes hide.

## Who it is for

This template is for Drupal developers who start projects regularly and want a consistent application foundation without prescribing how they run PHP, databases, containers, or hosting.

Those choices belong to each developer and project. The repetitive Drupal setup does not have to.

## In short

This template turns the repeated first phase of a Drupal project into a reusable starting point, giving you a clean installation, environment-aware configuration, safer file locations, useful development settings, and the everyday deployment helpers needed to move forward.
