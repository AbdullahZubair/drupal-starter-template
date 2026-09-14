<?php

/**
 * @file
 * Load environment variables from the .env file.
 */

use Symfony\Component\Dotenv\Dotenv;

(new Dotenv())->usePutenv()->bootEnv(DRUPAL_ROOT . '/../.env', 'dev', ['test'], TRUE);
