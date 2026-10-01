-- =====================================================================
-- Smart Fare Vending Bus System  |  database/schema.sql
-- Target: XAMPP (MariaDB / MySQL), phpMyAdmin import
-- Import: phpMyAdmin > Import > choose this file > Go
-- =====================================================================

DROP DATABASE IF EXISTS smart_fare;
CREATE DATABASE smart_fare
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE smart_fare;

-- ---------------------------------------------------------------------
-- 1. users : admin dashboard accounts
-- ---------------------------------------------------------------------
CREATE TABLE users (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(100) NOT NULL,
  username      VARCHAR(50)  NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,              -- PHP password_hash() output
  role          ENUM('admin','operator','conductor') NOT NULL DEFAULT 'operator',
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  last_login    DATETIME     NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. fare_types : Regular / Student / Senior Citizen
-- ---------------------------------------------------------------------
CREATE TABLE fare_types (
  id               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name             VARCHAR(30)  NOT NULL UNIQUE,
  discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0.00,
  is_active        TINYINT(1)   NOT NULL DEFAULT 1,
  CONSTRAINT chk_discount CHECK (discount_percent >= 0 AND discount_percent <= 100)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. routes : origin, destination, base fare
-- ---------------------------------------------------------------------
CREATE TABLE routes (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  origin      VARCHAR(80)  NOT NULL,
  destination VARCHAR(80)  NOT NULL,
  base_fare   DECIMAL(8,2) NOT NULL,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_route (origin, destination),
  CONSTRAINT chk_base_fare CHECK (base_fare > 0)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. terminals : each vending terminal / bus unit
-- ---------------------------------------------------------------------
CREATE TABLE terminals (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(50) NOT NULL UNIQUE,         -- e.g. "Bus 01 Terminal"
  bus_number  VARCHAR(20) NULL,
  status      ENUM('online','offline','maintenance') NOT NULL DEFAULT 'online',
  last_active DATETIME    NULL,
  created_at  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. transactions : one row per completed/cancelled/failed payment
--    Route and fare type NAMES and the fare are stored as a snapshot so
--    old records stay correct even if an admin later edits the route.
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  reference_no   VARCHAR(20)  NOT NULL UNIQUE,     -- e.g. SFV-20261001-0001
  route_id       INT UNSIGNED NOT NULL,
  fare_type_id   INT UNSIGNED NOT NULL,
  terminal_id    INT UNSIGNED NOT NULL,
  route_label    VARCHAR(170) NOT NULL,            -- snapshot "Origin - Destination"
  fare_type_name VARCHAR(30)  NOT NULL,            -- snapshot
  base_fare      DECIMAL(8,2) NOT NULL,            -- snapshot
  discount_percent DECIMAL(5,2) NOT NULL DEFAULT 0.00, -- snapshot
  fare_amount    DECIMAL(8,2) NOT NULL,            -- final fare after discount
  cash_received  DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  change_given   DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  status         ENUM('completed','cancelled','failed') NOT NULL DEFAULT 'completed',
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tx_route    FOREIGN KEY (route_id)     REFERENCES routes(id),
  CONSTRAINT fk_tx_faretype FOREIGN KEY (fare_type_id) REFERENCES fare_types(id),
  CONSTRAINT fk_tx_terminal FOREIGN KEY (terminal_id)  REFERENCES terminals(id),
  CONSTRAINT chk_tx_amounts CHECK (fare_amount >= 0 AND cash_received >= 0 AND change_given >= 0),
  INDEX idx_tx_created (created_at),
  INDEX idx_tx_route (route_id),
  INDEX idx_tx_faretype (fare_type_id),
  INDEX idx_tx_status (status)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. transaction_cash_log : every denomination inserted (audit trail)
-- ---------------------------------------------------------------------
CREATE TABLE transaction_cash_log (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  transaction_id INT UNSIGNED NOT NULL,
  denomination   SMALLINT UNSIGNED NOT NULL,       -- 1,5,10,20,50,100
  quantity       SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  CONSTRAINT fk_cash_tx FOREIGN KEY (transaction_id)
    REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT chk_denom CHECK (denomination IN (1,5,10,20,50,100))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. change_log : denomination breakdown of the change given
-- ---------------------------------------------------------------------
CREATE TABLE change_log (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  transaction_id INT UNSIGNED NOT NULL,
  denomination   SMALLINT UNSIGNED NOT NULL,
  quantity       SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  CONSTRAINT fk_change_tx FOREIGN KEY (transaction_id)
    REFERENCES transactions(id) ON DELETE CASCADE,
  CONSTRAINT chk_change_denom CHECK (denomination IN (1,5,10,20,50,100))
) ENGINE=InnoDB;

-- =====================================================================
-- SEED DATA
-- =====================================================================

-- Default logins (CHANGE THESE after first login). Password for all: admin123
INSERT INTO users (full_name, username, password_hash, role) VALUES
('System Administrator', 'admin',    '$2y$10$mHDym40MeilAti4rSRvSDeYrB4MnoXpJpL4Oqvem./543oiddUeHu', 'admin'),
('Bus Operator',         'operator', '$2y$10$mHDym40MeilAti4rSRvSDeYrB4MnoXpJpL4Oqvem./543oiddUeHu', 'operator');

INSERT INTO fare_types (name, discount_percent) VALUES
('Regular',        0.00),
('Student',       20.00),
('Senior Citizen',20.00);

-- Sample routes only (not official fares)
INSERT INTO routes (origin, destination, base_fare) VALUES
('Cebu City Terminal', 'Talisay City',   20.00),
('Cebu City Terminal', 'Minglanilla',    28.00),
('Cebu City Terminal', 'Naga City',      35.00),
('Cebu City Terminal', 'Carcar City',    60.00),
('Cebu City Terminal', 'Danao City',     55.00),
('Cebu City Terminal', 'Consolacion',    30.00),
('Cebu City Terminal', 'Mandaue City',   15.00),
('Cebu City Terminal', 'Lapu-Lapu City', 25.00),
('Cebu City Terminal', 'Toledo City',    80.00),
('Cebu City Terminal', 'Bogo City',     120.00);

INSERT INTO terminals (name, bus_number, status, last_active) VALUES
('Bus 01 Terminal', 'BUS-001', 'online', NOW()),
('Bus 02 Terminal', 'BUS-002', 'offline', NULL);

-- Sample transactions so the dashboard has data on day one
INSERT INTO transactions
 (reference_no, route_id, fare_type_id, terminal_id, route_label, fare_type_name,
  base_fare, discount_percent, fare_amount, cash_received, change_given, status)
VALUES
('SFV-SEED-0001', 1, 1, 1, 'Cebu City Terminal - Talisay City', 'Regular',        20.00,  0.00, 20.00,  50.00, 30.00, 'completed'),
('SFV-SEED-0002', 3, 2, 1, 'Cebu City Terminal - Naga City',    'Student',        35.00, 20.00, 28.00,  50.00, 22.00, 'completed'),
('SFV-SEED-0003', 4, 3, 1, 'Cebu City Terminal - Carcar City',  'Senior Citizen', 60.00, 20.00, 48.00, 100.00, 52.00, 'completed');

INSERT INTO transaction_cash_log (transaction_id, denomination, quantity) VALUES
(1, 50, 1), (2, 50, 1), (3, 100, 1);

INSERT INTO change_log (transaction_id, denomination, quantity) VALUES
(1, 20, 1), (1, 10, 1),
(2, 20, 1), (2, 1, 2),
(3, 50, 1), (3, 1, 2);

-- =====================================================================
-- USEFUL QUERIES (for dashboard / testing)
-- =====================================================================
-- Total collections today:
--   SELECT COALESCE(SUM(fare_amount),0) FROM transactions
--   WHERE status='completed' AND DATE(created_at)=CURDATE();
--
-- Transactions today:
--   SELECT COUNT(*) FROM transactions
--   WHERE status='completed' AND DATE(created_at)=CURDATE();
--
-- Collections per day (chart):
--   SELECT DATE(created_at) AS day, SUM(fare_amount) AS total
--   FROM transactions WHERE status='completed'
--   GROUP BY DATE(created_at) ORDER BY day DESC LIMIT 7;
--
-- Active routes with fare for a fare type (vending screen):
--   SELECT r.id, r.origin, r.destination, r.base_fare,
--          ROUND(r.base_fare * (1 - f.discount_percent/100)) AS fare
--   FROM routes r JOIN fare_types f ON f.id = :fare_type_id
--   WHERE r.is_active = 1;
