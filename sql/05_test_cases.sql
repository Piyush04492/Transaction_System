-- ============================================================================
-- 05_test_cases.sql : Quick Verification Suite for Interviews
-- ============================================================================

USE `banking_db`;

-- 1. Initial State
SELECT '1. Initial Balances (A = 10,000 | B = 5,000)' AS Scenario;
SELECT account_id, holder_name, balance, daily_limit, status FROM accounts;

-- 2. Success Case: Transfer ₹2,000 from Account A (101) to Account B (102)
SELECT '2. Transfer ₹2,000 from 101 to 102' AS Scenario;
CALL sp_transfer_money(101, 102, 2000.00, 'KEY-001');

-- Verify Balances (Expected: 101 has 8,000 | 102 has 7,000)
SELECT account_id, holder_name, balance FROM accounts WHERE account_id IN (101, 102);

-- 3. Rollback Case: Insufficient Funds (Try to transfer ₹15,000 from 101)
SELECT '3. Overdraft Transfer Attempt (₹15,000 from 101) -> ROLLBACK' AS Scenario;
CALL sp_transfer_money(101, 102, 15000.00, 'KEY-002');

-- Verify Balances Unchanged (Still 8,000 and 7,000)
SELECT account_id, balance FROM accounts WHERE account_id IN (101, 102);

-- 4. Duplicate Transaction Case: Re-sending KEY-001
SELECT '4. Replay Duplicate Key (KEY-001) -> IGNORED' AS Scenario;
CALL sp_transfer_money(101, 102, 2000.00, 'KEY-001');

-- 5. Daily Limit Case: Account 103 has daily limit of ₹3,000
SELECT '5. Exceed Daily Limit (₹4,000 from 103) -> REJECTED' AS Scenario;
CALL sp_transfer_money(103, 101, 4000.00, 'KEY-003');

-- 6. Frozen Account Case: Try to update Account 104
SELECT '6. Transfer to Frozen Account 104 -> REJECTED' AS Scenario;
CALL sp_transfer_money(101, 104, 500.00, 'KEY-004');

-- 7. View Automatic Trigger Audit Logs
SELECT '7. Automatic Trigger Audit Trail (transaction_logs)' AS Scenario;
SELECT * FROM transaction_logs ORDER BY log_id DESC LIMIT 10;
