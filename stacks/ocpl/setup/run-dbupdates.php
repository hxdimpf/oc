<?php
// Run every OCPL DB update once (the Admin.DbUpdate page needs an admin login).
// An update that fails because the schema already contains its change is reported, not fatal.
chdir('/var/www/html');
$_SERVER['HTTP_HOST'] = 'localhost';
require '/var/www/html/lib/common.inc.php';
use src\Utils\Database\DbUpdates;
foreach (DbUpdates::getAll() as $uuid => $update) {
    $name = $update->getName();
    if (preg_match('/^00[0-9]_test/', $name)) { continue; }  // demo updates (one sleeps 10 minutes)
    try {
        $update->run();
        echo "ok      $name\n";
    } catch (\Throwable $e) {
        echo "failed  $name: " . strtok($e->getMessage(), "\n") . "\n";
    }
}
DbUpdates::updateRoutines();
echo "routines updated\n";
