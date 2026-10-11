#!/usr/bin/env python3
"""Build an OCPL database schema from an opencaching-pl checkout.

Usage: build-schema.py <opencaching-pl dir> > ocpl-schema.sql

Sources (all in the repo):
  - docs/database/*: one file per table with SHOW CREATE TABLE output
  - docs/sql/tables/ocpl.sql.gz: 2012 dump, only for tables the static data
    still needs but docs/database lacks
The OKAPI additions to OCPL tables (okapi_syncbase columns and indexes, the
cache_logs uuid index) are removed, so that okapi/update adds them itself.
OKAPI's own okapi_* tables are left out for the same reason.
"""
import gzip
import os
import re
import sys

repo = sys.argv[1]
docs = os.path.join(repo, 'docs', 'database')
LEGACY_TABLES = ['sys_menu', 'nodes', 'logentries_types']
OKAPI_SYNCBASE_TABLES = {'caches', 'cache_logs', 'cache_logs_archived'}


def strip_okapi(name, stmt):
    lines = stmt.split('\n')
    out = []
    for line in lines:
        if name in OKAPI_SYNCBASE_TABLES and 'okapi_syncbase' in line:
            continue
        if name == 'cache_logs' and re.match(r'\s*KEY `uuid` \(`uuid`\)', line):
            continue
        out.append(line)
    # a removed last column/key can leave a trailing comma before ")"
    text = '\n'.join(out)
    return re.sub(r',\n\)', '\n)', text)


statements = []
for name in sorted(os.listdir(docs)):
    if name.startswith('!') or name.startswith('okapi_'):
        continue
    text = open(os.path.join(docs, name), encoding='utf-8', errors='replace').read()
    m = re.search(r'(CREATE TABLE `([^`]+)` \(.*?\n\)[^\n]*)', text, re.S)
    if not m:
        sys.exit(f'no CREATE TABLE in docs/database/{name}')
    statements.append(strip_okapi(m.group(2), m.group(1).rstrip().rstrip(';')) + ';')

legacy = gzip.open(os.path.join(repo, 'docs', 'sql', 'tables', 'ocpl.sql.gz'), 'rt', encoding='utf-8', errors='replace').read()
for name in LEGACY_TABLES:
    m = re.search(r'(CREATE TABLE[^\n]*`' + name + r'` \(.*?\n\)[^\n]*;)', legacy, re.S)
    if not m:
        sys.exit(f'legacy table {name} not found')
    statements.append(m.group(1))

print('SET FOREIGN_KEY_CHECKS=0;')
print('\n\n'.join(statements))
print(f'-- {len(statements)} tables', file=sys.stderr)
