-- Columns used by the code/routines but missing from docs/database (schema drift).
ALTER TABLE caches ADD COLUMN IF NOT EXISTS date_published DATETIME NULL DEFAULT NULL;
