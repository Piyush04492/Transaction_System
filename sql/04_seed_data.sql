-- ============================================================================
-- 04_seed_data.sql : Seed Data Matching Prompt Example
-- Account A (101): ₹10,000
-- Account B (102): ₹5,000
-- Account C (103): ₹2,000 with low daily limit (₹3,000)
-- Account D (104): FROZEN account
-- ============================================================================

USE `banking_db`;

SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE `transaction_logs`;
TRUNCATE TABLE `transactions`;
TRUNCATE TABLE `accounts`;
SET FOREIGN_KEY_CHECKS = 1;

-- Insert Accounts
INSERT INTO `accounts` (`account_id`, `holder_name`, `balance`, `daily_limit`, `status`)
VALUES
    (101, 'Account A (Aditi)', 10000.00, 25000.00, 'ACTIVE'),
    (102, 'Account B (Rohan)',  5000.00, 25000.00, 'ACTIVE'),
    (103, 'Account C (Priya)',  2000.00,  3000.00, 'ACTIVE'),
    (104, 'Account D (Vikram)', 1000.00, 10000.00, 'FROZEN');

-- Record Opening Balances
INSERT INTO `transactions` (`from_account_id`, `to_account_id`, `amount`, `txn_type`)
VALUES
    (NULL, 101, 10000.00, 'DEPOSIT'),
    (NULL, 102,  5000.00, 'DEPOSIT'),
    (NULL, 103,  2000.00, 'DEPOSIT');
