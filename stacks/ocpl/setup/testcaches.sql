-- Three test caches owned by octeam (user 1), so ocuser (user 2, the OKAPI test user) can log them.
SET SQL_MODE='';
INSERT INTO caches (cache_id, user_id, name, latitude, longitude, type, status, country, date_hidden, date_created, last_modified,
                    size, difficulty, terrain, wp_oc, uuid, default_desclang, desc_languages, founds, notfounds, notes, watcher, picturescount)
VALUES
 (1, 1, 'Test Traditional', 52.2297, 21.0122, 2, 1, 'PL', NOW(), NOW(), NOW(), 3, 3, 3, 'OP0001', UUID(), 'EN', 'EN', 0, 0, 0, 0, 0),
 (2, 1, 'Test Multicache',  52.2350, 21.0200, 3, 1, 'PL', NOW(), NOW(), NOW(), 4, 5, 4, 'OP0002', UUID(), 'EN', 'EN', 0, 0, 0, 0, 0),
 (3, 1, 'Test Event',       52.2400, 21.0300, 6, 1, 'PL', NOW(), NOW(), NOW(), 7, 2, 2, 'OP0003', UUID(), 'EN', 'EN', 0, 0, 0, 0, 0);
INSERT INTO cache_desc (cache_id, language, `desc`, short_desc, hint, date_created, last_modified, rr_comment, uuid, node)
VALUES
 (1, 'EN', '<p>Test cache for the OKAPI test suite.</p>', 'Test cache', '', NOW(), NOW(), '', UUID(), 2),
 (2, 'EN', '<p>Test cache for the OKAPI test suite.</p>', 'Test cache', '', NOW(), NOW(), '', UUID(), 2),
 (3, 'EN', '<p>Test event for the OKAPI test suite.</p>', 'Test event', '', NOW(), NOW(), '', UUID(), 2);

-- update 100_init makes these columns NOT NULL (as on OCPL); the test data leaves them NULL
UPDATE caches SET wp_gc = COALESCE(wp_gc, ''), wp_nc = COALESCE(wp_nc, ''), wp_ge = COALESCE(wp_ge, ''), wp_tc = COALESCE(wp_tc, '');
UPDATE cache_logs SET text_html = COALESCE(text_html, 0);
UPDATE user SET statpic_text = COALESCE(statpic_text, '');
UPDATE PowerTrail_comments SET deleted = COALESCE(deleted, 0);
