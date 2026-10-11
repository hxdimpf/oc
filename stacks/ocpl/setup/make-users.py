#!/usr/bin/env python3
"""Turn the user rows of the OCPL static data into an INSERT the current schema accepts.

Usage: make-users.py <opencaching-pl dir> <file with the user table's column names> > users.sql

docs/sql/static-data/data.sql is older than the schema: its user INSERT names columns
that no longer exist (e.g. login_faults). Keep only the existing columns, and give every
user a unique UUID (the static data uses one placeholder for all, which would make OKAPI
treat every user as the owner of every cache).
"""
import re
import sys

repo, colfile = sys.argv[1], sys.argv[2]
cols = set(open(colfile).read().split())
data = open(f'{repo}/docs/sql/static-data/data.sql', encoding='utf-8').read()
m = re.search(r"INSERT INTO `user` \((.*?)\) VALUES\n(.*?);\n", data, re.S)
names = [c.strip().strip('`') for c in m.group(1).split(',')]
keep = [i for i, n in enumerate(names) if n in cols]
rows = []
for row in re.findall(r"^\((.*)\),?$", m.group(2), re.M):
    vals = [v.strip() for v in re.findall(r"'(?:[^'\\]|\\.)*'|[^,]+", row)]
    if len(vals) != len(names):
        sys.exit(f'cannot parse user row: {row[:60]}')
    rows.append('(' + ', '.join(vals[i] for i in keep) + ')')
print("SET SQL_MODE='';")
print('INSERT INTO `user` (' + ', '.join(f'`{names[i]}`' for i in keep) + ') VALUES')
print(',\n'.join(rows) + ';')
print('UPDATE `user` SET uuid = UUID(), uuid_mobile = UUID();')
