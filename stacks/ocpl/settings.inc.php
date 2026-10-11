<?php
// OCPL test installation: mounted as lib/settings.inc.php (see docker-compose.yml).
// Start from OCPL's own example settings (they define everything the code expects)
// and override only what differs here; values come from the container environment.
require __DIR__ . '/settings-example.inc.php';

// OKAPI needs a URL with a scheme here
$absolute_server_URI = getenv('OCPL_SITE_URL');
$mp3url = '/mp3';
$config['cookie']['domain'] = '';

$dbserver = getenv('OCPL_DB_HOST');
$dbname = getenv('OCPL_DB_NAME');
$dbusername = getenv('OCPL_DB_USER');
$dbpasswd = getenv('OCPL_DB_PASS');
$opt['db']['admin_username'] = $dbusername;   // automatic DB updates
$opt['db']['admin_password'] = $dbpasswd;
