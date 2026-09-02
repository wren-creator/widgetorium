<?php
// Admin panel configuration.
// API key moved out of source control, see WIDGETORIUM_API_KEY in the env.
// (The pre-rewrite version, with the key in cleartext, is still in this
//  directory's git history: vuln 9.)
define('WIDGETORIUM_API_KEY', getenv('WIDGETORIUM_API_KEY') ?: '');
define('DB_DSN', 'mysql:host=' . (getenv('DB_HOST') ?: 'db') . ';dbname=' . (getenv('DB_NAME') ?: 'widgetorium'));
define('DB_USER', getenv('DB_USER') ?: 'widgetorium');
define('DB_PASS', getenv('DB_PASS') ?: 'widgetorium');
