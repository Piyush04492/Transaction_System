-- ============================================================================
-- 01_schema.sql : Clean, Intermediate-Level Schema for Banking System
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `banking_db`;
USE `banking_db`;

DROP TABLE IF EXISTS `transaction_logs`;
DROP TABLE IF EXISTS `transactions`;
DROP TABLE IF EXISTS `accounts`;

-- 1. Accounts Table
CREATE TABLE `accounts` (
    `account_id`   INT PRIMARY KEY,
    `holder_name`  VARCHAR(50) NOT NULL,
    `balance`      DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    `daily_limit`  DECIMAL(12, 2) NOT NULL DEFAULT 20000.00,
    `status`       VARCHAR(10) NOT NULL DEFAULT 'ACTIVE',  -- 'ACTIVE' or 'FROZEN'
    CONSTRAINT `chk_balance_positive` CHECK (`balance` >= 0)
) ENGINE=InnoDB;

-- 2. Transactions Table
CREATE TABLE `transactions` (
    `txn_id`           INT AUTO_INCREMENT PRIMARY KEY,
    `idempotency_key`  VARCHAR(50) UNIQUE NULL,            -- Prevents duplicate transfers
    `from_account_id`  INT NULL,                           -- NULL for direct deposits
    `to_account_id`    INT NULL,                           -- NULL for direct withdrawals
    `amount`           DECIMAL(12, 2) NOT NULL,
    `txn_type`         VARCHAR(15) NOT NULL,               -- 'TRANSFER', 'DEPOSIT', 'WITHDRAW'
    `created_at`       DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`from_account_id`) REFERENCES `accounts`(`account_id`),
    FOREIGN KEY (`to_account_id`) REFERENCES `accounts`(`account_id`),
    CONSTRAINT `chk_amount_positive` CHECK (`amount` > 0)
) ENGINE=InnoDB;

-- 3. Transaction Logs (Audit Trail maintained automatically by Triggers)
CREATE TABLE `transaction_logs` (
    `log_id`         INT AUTO_INCREMENT PRIMARY KEY,
    `account_id`     INT NOT NULL,
    `old_balance`    DECIMAL(12, 2) NOT NULL,
    `new_balance`    DECIMAL(12, 2) NOT NULL,
    `change_amount`  DECIMAL(12, 2) NOT NULL,
    `logged_at`      DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`account_id`) REFERENCES `accounts`(`account_id`)
) ENGINE=InnoDB;
