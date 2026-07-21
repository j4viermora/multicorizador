-- The MariaDB image only grants MARIADB_USER access to MARIADB_DATABASE, but
-- Rails needs to create and drop the queue and test databases too (db:prepare,
-- db:test:prepare). Widen the grant to every ruka_* schema.
GRANT ALL PRIVILEGES ON `ruka\_%`.* TO 'ruka'@'%';
FLUSH PRIVILEGES;
