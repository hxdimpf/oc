#!/bin/bash
# (Re)build the ocpl10 test installation: like setup-ocpl.sh, but in the ocpl10 stack on
# MariaDB 10.0 (stack mariadb10). WIPES its ocpl database. Run on the VM as root:
#   /opt/stacks/ocpl/setup/setup-ocpl10.sh --dump
# The devel dump is shared with the ocpl stack (/opt/stacks/ocpl/cache/).
here=$(cd "$(dirname "$0")" && pwd)
STACK=/opt/stacks/ocpl10 CACHE=$(dirname "$here")/cache APP=ocpl10-ocpl10-1 DBC=mariadb10-db10-1 \
DB_CLIENT=mysql SITE=ocpl10 exec "$here/setup-ocpl.sh" "$@"
