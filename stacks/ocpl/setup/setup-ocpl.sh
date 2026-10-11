#!/bin/bash
# (Re)build the OCPL test installation: database, OCPL DB updates, OKAPI, test data.
# WIPES the ocpl database. Run on the VM as root:
#   /opt/stacks/ocpl/setup/setup-ocpl.sh
#
# Steps:
#  1. database ocpl + user ocpl in the shared MariaDB (password = DB_PASSWORD of the stack)
#  2. schema built from the repo (docs/database, see build-schema.py) + schema-patches.sql
#  3. static data, triggers/procedures, the default users (make-users.py), 3 test caches
#  4. OCPL DB updates (run-dbupdates.php), then the OKAPI install (okapi/update)
#  5. an OKAPI consumer + access token for user "ocuser", written to
#     /opt/stacks/ocpl/okapi-test-credentials (root only) for tests/config.js
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
stack=$(dirname "$here")
repo=${REPO:-/opt/repos/opencaching-pl}
app=${APP:-ocpl-ocpl-1}
dbc=${DBC:-mariadb-db-1}
set -a; . "$stack/.env"; set +a

root() { docker exec -i "$dbc" mariadb -uroot -p"$DB_PASSWORD" "$@"; }

echo "== 1. database"
root -e "DROP DATABASE IF EXISTS ocpl; CREATE DATABASE ocpl CHARACTER SET utf8mb4;
  CREATE USER IF NOT EXISTS 'ocpl'@'%' IDENTIFIED BY '$DB_PASSWORD';
  ALTER USER 'ocpl'@'%' IDENTIFIED BY '$DB_PASSWORD';
  GRANT ALL ON ocpl.* TO 'ocpl'@'%'; GRANT SUPER ON *.* TO 'ocpl'@'%';"

echo "== 2. schema"
python3 -I "$here/build-schema.py" "$repo" | root ocpl
root ocpl < "$here/schema-patches.sql"

echo "== 3. static data, routines, users, test caches"
# the static data is older than the schema: its user rows fail (make-users.py adds them)
root --force ocpl < "$repo/docs/sql/static-data/data.sql" 2>&1 | grep ERROR | grep -v login_faults || true
for f in common caches cache_desc cache_logs cache_rating cache_watches; do
    root ocpl < "$repo/resources/sql/routines/$f.sql"
done
root -N ocpl -e "select column_name from information_schema.columns where table_schema='ocpl' and table_name='user'" > /tmp/ocpl-usercols
python3 -I "$here/make-users.py" "$repo" /tmp/ocpl-usercols | root ocpl
root ocpl < "$here/testcaches.sql"

echo "== 4. OCPL DB updates, OKAPI install"
docker exec -i "$app" php < "$here/run-dbupdates.php" | grep -E "^(ok|failed|routines)"
out=$(docker exec "$app" curl -s "http://localhost/okapi/update?install=true" | sed 's/<[^>]*>//g')
if echo "$out" | grep -q "ERROR"; then echo "$out" | grep -A6 "ERROR"; exit 1; fi
echo "OKAPI db_version: $(root -N ocpl -e "select value from okapi_vars where var='db_version'")"

echo "== 5. OKAPI test credentials (user ocuser)"
ck=$(openssl rand -hex 10); cs=$(openssl rand -hex 20); tk=$(openssl rand -hex 10); ts=$(openssl rand -hex 20)
root ocpl -e "INSERT INTO okapi_consumers (\`key\`,name,secret,email,date_created) VALUES ('$ck','OKAPI test suite','$cs','test@localhost',NOW());
  INSERT INTO okapi_tokens (\`key\`,secret,token_type,timestamp,user_id,consumer_key) VALUES ('$tk','$ts','access',UNIX_TIMESTAMP(),2,'$ck');
  INSERT INTO okapi_authorizations (consumer_key,user_id,last_access_token) VALUES ('$ck',2,NOW());"
umask 077
cat > "$stack/okapi-test-credentials" <<EOT
// for okapi/tests/config.js, targets:
ocpl: { baseUrl: 'http://ocpl.$DOMAIN_SUFFIX', consumerKey: '$ck', consumerSecret: '$cs', accessToken: '$tk', tokenSecret: '$ts', allowWrite: true },
EOT
echo "written: $stack/okapi-test-credentials"
