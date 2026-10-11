<?php
// OCPL test installation: mounted as lib/settings.inc.php (see docker-compose.yml).
// Based on lib/settings-example.inc.php; values come from the container environment.
require __DIR__ . '/settingsDefault.inc.php';

date_default_timezone_set('Europe/Warsaw');

// node: pl (OC_BRANCH oc.pl in OKAPI)
$config['ocNode'] = 'pl';
$GLOBALS['oc_waypoint'] = 'OP';

$config['cookie']['name'] = 'oc';
$config['cookie']['path'] = '/';
$config['cookie']['domain'] = '';
$config['mainLayout']['displayOnlineUsers'] = true;

$NEED_FIND_LIMIT = 10;
$NEED_APPROVE_LIMIT = 3;

// OKAPI needs a URL with a scheme here
$absolute_server_URI = getenv('OCPL_SITE_URL');

$dynbasepath = '/var/www/ocpl-data/';
$mp3dir = $dynbasepath . 'mp3';
$mp3url = '/mp3';
$maxmp3size = 5000000;
$mp3extensions = ';mp3;';

$dbserver = getenv('OCPL_DB_HOST');
$dbname = getenv('OCPL_DB_NAME');
$dbusername = getenv('OCPL_DB_USER');
$dbpasswd = getenv('OCPL_DB_PASS');
$dbcharset = 'utf8mb4';
$opt['db']['admin_username'] = $dbusername;   // automatic DB updates
$opt['db']['admin_password'] = $dbpasswd;

$googlemap_key = '';
$cache_params_url = 'http://wiki.opencaching.pl/index.php/Parametry_skrzynki';
$contactDataPL = [];
