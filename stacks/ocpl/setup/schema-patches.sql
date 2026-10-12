-- Columns used by the code/routines but missing from docs/database (schema drift).
ALTER TABLE caches ADD COLUMN IF NOT EXISTS date_published DATETIME NULL DEFAULT NULL;
ALTER TABLE user ADD COLUMN IF NOT EXISTS role SET('ocTeamMember','advUser','newsPublisher','sysAdmin') NOT NULL DEFAULT '';

-- Tables used by the code but missing from docs/database; definitions taken from an old (2018) OCPL
-- developer VM, structure only. To be replaced by the current OCPL schema dump.
CREATE TABLE IF NOT EXISTS `badges` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(30) NOT NULL,
  `category_id` int(11) NOT NULL,
  `sequence` int(11) NOT NULL,
  `picture` varchar(255) NOT NULL,
  `trigger_type` int(11) NOT NULL COMMENT '    NONE = 0;       CRON = 1;      LOG_CACHE = 2;     LOG_CACHE_AUTHOR = 3;     TITLED_CACHE = 4;      TITLED_CACHE_AUTHOR = 5;         LOG_GEOPATH = 6;     LOG_GEOPATH_AUTHOR = 7;     RECOMMENDATION = 8;',
  `belonging_query` text NOT NULL,
  `gained_query` text NOT NULL,
  `short_description` char(100) NOT NULL,
  `description` text NOT NULL,
  `cfg_period_threshold` char(1) NOT NULL COMMENT 'Table in badge.php: Level of the badge. Column: (P)eriod or (T)hreshold',
  `cfg_show_positions` char(2) NOT NULL COMMENT '- none, L - list, M - map',
  `graphic_author` text NOT NULL,
  `description_author` text NOT NULL,
  `attendant` text NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `badge_area` (
  `badge_id` int(11) NOT NULL,
  `shape` geometry NOT NULL,
  PRIMARY KEY (`badge_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `badge_cache` (
  `badge_id` int(11) NOT NULL,
  `cache_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `badge_categories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `sequence` int(11) NOT NULL,
  `name` varchar(30) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `badge_levels` (
  `badge_id` int(11) NOT NULL,
  `level` int(11) NOT NULL,
  `name` varchar(30) DEFAULT NULL,
  `threshold` int(11) NOT NULL,
  `picture` varchar(255) DEFAULT NULL COMMENT 'path to the picuture of level',
  PRIMARY KEY (`badge_id`,`level`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `badge_user` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `badge_id` int(11) NOT NULL,
  `level_id` int(11) NOT NULL,
  `level_date` datetime NOT NULL,
  `prev_val` int(11) NOT NULL,
  `curr_val` int(11) NOT NULL,
  `next_val` int(11) NOT NULL,
  `description` text NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`,`badge_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `CACHE_ACCESS_LOGS` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `event_date` datetime NOT NULL,
  `cache_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `source` varchar(2) NOT NULL COMMENT 'B - browser - main opencaching site, M - mobile, O - okapi',
  `event` varchar(32) NOT NULL COMMENT 'viewcache, viewlogs, ... ',
  `ip_addr` varchar(32) NOT NULL COMMENT 'request IP',
  `user_agent` varchar(128) DEFAULT NULL COMMENT 'User-Agent HTTP header',
  `forwarded_for` varchar(128) DEFAULT NULL COMMENT 'X-Forwarded-For HTTP header',
  `okapi_consumer_key` varchar(20) DEFAULT NULL COMMENT 'OKAPI consumer key',
  `info_text` varchar(2048) DEFAULT NULL COMMENT 'Free info text',
  PRIMARY KEY (`id`),
  KEY `access_logs_cache_id` (`cache_id`),
  KEY `access_logs_user_id` (`user_id`),
  KEY `event_date` (`event_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `cache_visits2` (
  `cache_id` int(11) NOT NULL,
  `user_id_ip` varchar(15) NOT NULL COMMENT 'user_id or used IP address',
  `type` varchar(1) NOT NULL COMMENT 'C=cache_visits; U=last_user_unique_visit; P=prepublication_user_visit',
  `count` int(11) NOT NULL DEFAULT '0',
  `visit_date` datetime NOT NULL,
  PRIMARY KEY (`cache_id`,`user_id_ip`,`type`),
  KEY `type` (`type`,`visit_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='User visits at geocache webpage counter';
CREATE TABLE IF NOT EXISTS `geokret_log` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `log_date_time` datetime NOT NULL,
  `enqueue_date_time` datetime NOT NULL,
  `user_id` int(11) NOT NULL,
  `geocache_id` int(11) NOT NULL,
  `log_type` int(11) NOT NULL,
  `comment` varchar(160) NOT NULL,
  `tracking_code` varchar(10) NOT NULL,
  `geokret_id` int(11) NOT NULL,
  `geokret_name` varchar(160) NOT NULL,
  `last_try` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `enqueue_date_time` (`enqueue_date_time`),
  KEY `last_try_index` (`last_try`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `powertrail_progress` (
  `user_id` int(11) NOT NULL,
  `pt_id` int(11) NOT NULL,
  `founds` int(11) NOT NULL,
  PRIMARY KEY (`user_id`,`pt_id`),
  KEY `pt_id` (`pt_id`),
  KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE IF NOT EXISTS `user_neighbourhoods` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `seq` int(11) NOT NULL COMMENT 'Number in sequence',
  `name` tinytext NOT NULL,
  `longitude` double NOT NULL,
  `latitude` double NOT NULL,
  `radius` int(11) NOT NULL,
  `notify` tinyint(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id_2` (`user_id`,`seq`),
  KEY `user_id` (`user_id`),
  KEY `seq` (`seq`),
  KEY `notify` (`notify`),
  CONSTRAINT `user_neighbourhoods_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='Stores additional user MyNeighborhood areas';
CREATE TABLE IF NOT EXISTS `user_preferences` (
  `user_id` int(11) NOT NULL,
  `key` varchar(25) NOT NULL COMMENT 'key identifies set of user preferences ',
  `value` text,
  PRIMARY KEY (`user_id`,`key`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `user_preferences_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='minor user setting in context of UI';

-- Old columns from the same VM that update 100_init changes and updates 104/109 drop again;
-- with them the update chain runs as on a real OCPL database (defaults added for strict mode).
ALTER TABLE cache_desc ADD COLUMN IF NOT EXISTS desc_htmledit tinyint(1) NOT NULL DEFAULT 0;
ALTER TABLE caches ADD COLUMN IF NOT EXISTS wp_nc varchar(6) NOT NULL DEFAULT '',
                   ADD COLUMN IF NOT EXISTS wp_ge varchar(7) NOT NULL DEFAULT '',
                   ADD COLUMN IF NOT EXISTS wp_qc varchar(10) NULL DEFAULT NULL;
ALTER TABLE user ADD COLUMN IF NOT EXISTS cache_ignores int(11) NULL DEFAULT 0,
                 ADD COLUMN IF NOT EXISTS admin tinyint(1) NOT NULL DEFAULT 0;
