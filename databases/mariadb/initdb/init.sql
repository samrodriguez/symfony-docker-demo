CREATE DATABASE IF NOT EXISTS symfonydemo
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON symfonydemo.* TO 'developer'@'%' IDENTIFIED BY 'developer';

FLUSH PRIVILEGES;