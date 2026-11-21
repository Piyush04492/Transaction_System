-- ============================================================================
-- 03_procedures.sql : Clean & Interview-Friendly Stored Procedures
-- Demonstrates: START TRANSACTION, COMMIT, ROLLBACK, SAVEPOINT,
--               ROW_COUNT() verification, SELECT ... FOR UPDATE,
--               Daily Limits, and Idempotency.
-- ============================================================================

USE `banking_db`;

DROP PROCEDURE IF EXISTS `sp_transfer_money`;
DROP PROCEDURE IF EXISTS `sp_deposit`;
DROP PROCEDURE IF EXISTS `sp_withdraw`;

DELIMITER $$

-- ----------------------------------------------------------------------------
-- 1. Transfer Money Between Accounts (Core Interview Procedure)
-- ----------------------------------------------------------------------------
CREATE PROCEDURE `sp_transfer_money`(
    IN p_from            INT,
    IN p_to              INT,
    IN p_amount          DECIMAL(12, 2),
    IN p_idempotency_key VARCHAR(50)
)
proc: BEGIN
    DECLARE v_today_total DECIMAL(12, 2) DEFAULT 0.00;
    DECLARE v_daily_limit DECIMAL(12, 2) DEFAULT 0.00;

    -- [ACID - Rollback Handler]: Rollback on any unexpected SQL error
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: Transaction rolled back due to an unexpected error.' AS status;
    END;

    -- Step 1: Input Validation
    IF p_amount <= 0 THEN
        SELECT 'FAILED: Transfer amount must be greater than zero.' AS status;
        LEAVE proc;
    END IF;

    IF p_from = p_to THEN
        SELECT 'FAILED: Source and destination accounts cannot be the same.' AS status;
        LEAVE proc;
    END IF;

    -- Step 2: Duplicate Prevention (Idempotency Check)
    IF p_idempotency_key IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM `transactions` WHERE `idempotency_key` = p_idempotency_key) THEN
            SELECT 'IGNORED: Duplicate transaction request detected.' AS status;
            LEAVE proc;
        END IF;
    END IF;

    -- Step 3: Daily Limit Check
    SELECT `daily_limit` INTO v_daily_limit FROM `accounts` WHERE `account_id` = p_from;
    
    SELECT COALESCE(SUM(amount), 0.00) INTO v_today_total
    FROM `transactions`
    WHERE `from_account_id` = p_from
      AND `txn_type` = 'TRANSFER'
      AND DATE(`created_at`) = CURDATE();

    IF (v_today_total + p_amount) > v_daily_limit THEN
        SELECT CONCAT('FAILED: Exceeds daily transfer limit of ₹', v_daily_limit) AS status;
        LEAVE proc;
    END IF;

    -- Step 4: BEGIN TRANSACTION (Atomicity starts here)
    START TRANSACTION;

    -- Step 5: Concurrency Control (Row-Level Locking to prevent race conditions)
    SELECT `balance` FROM `accounts`
    WHERE `account_id` IN (p_from, p_to)
    FOR UPDATE;

    -- Step 6: Debit Source Account (enforces balance >= amount)
    UPDATE `accounts`
    SET `balance` = `balance` - p_amount
    WHERE `account_id` = p_from
      AND `balance` >= p_amount;

    -- Step 7: Verify Debit affected exactly 1 row (Crucial Production Check!)
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;  -- Insufficient balance or invalid account: cancel everything!
        SELECT 'FAILED: Insufficient funds or invalid source account. Rolled back.' AS status;
        LEAVE proc;
    END IF;

    -- Step 8: SAVEPOINT (Intermediate recovery checkpoint)
    SAVEPOINT debit_checkpoint;

    -- Step 9: Credit Destination Account
    UPDATE `accounts`
    SET `balance` = `balance` + p_amount
    WHERE `account_id` = p_to;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK TO SAVEPOINT debit_checkpoint;
        ROLLBACK;
        SELECT 'FAILED: Destination account not found. Rolled back.' AS status;
        LEAVE proc;
    END IF;

    -- Step 10: Record in Master Transactions Table
    INSERT INTO `transactions` (
        `idempotency_key`, `from_account_id`, `to_account_id`, `amount`, `txn_type`
    ) VALUES (
        p_idempotency_key, p_from, p_to, p_amount, 'TRANSFER'
    );

    -- Step 11: COMMIT (Permanently save all changes)
    COMMIT;
    SELECT 'SUCCESS: Funds transferred successfully.' AS status;

END proc$$


-- ----------------------------------------------------------------------------
-- 2. Deposit Money
-- ----------------------------------------------------------------------------
CREATE PROCEDURE `sp_deposit`(
    IN p_account_id INT,
    IN p_amount     DECIMAL(12, 2)
)
proc: BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: Deposit failed and rolled back.' AS status;
    END;

    IF p_amount <= 0 THEN
        SELECT 'FAILED: Deposit amount must be positive.' AS status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    UPDATE `accounts`
    SET `balance` = `balance` + p_amount
    WHERE `account_id` = p_account_id;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SELECT 'FAILED: Account does not exist.' AS status;
        LEAVE proc;
    END IF;

    INSERT INTO `transactions` (`from_account_id`, `to_account_id`, `amount`, `txn_type`)
    VALUES (NULL, p_account_id, p_amount, 'DEPOSIT');

    COMMIT;
    SELECT 'SUCCESS: Deposit completed.' AS status;
END proc$$


-- ----------------------------------------------------------------------------
-- 3. Withdraw Money
-- ----------------------------------------------------------------------------
CREATE PROCEDURE `sp_withdraw`(
    IN p_account_id INT,
    IN p_amount     DECIMAL(12, 2)
)
proc: BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: Withdrawal failed and rolled back.' AS status;
    END;

    IF p_amount <= 0 THEN
        SELECT 'FAILED: Withdrawal amount must be positive.' AS status;
        LEAVE proc;
    END IF;

    START TRANSACTION;

    -- Debit with balance validation
    UPDATE `accounts`
    SET `balance` = `balance` - p_amount
    WHERE `account_id` = p_account_id
      AND `balance` >= p_amount;

    -- If 0 rows affected, balance was insufficient
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SELECT 'FAILED: Insufficient funds or account not found. Rolled back.' AS status;
        LEAVE proc;
    END IF;

    INSERT INTO `transactions` (`from_account_id`, `to_account_id`, `amount`, `txn_type`)
    VALUES (p_account_id, NULL, p_amount, 'WITHDRAW');

    COMMIT;
    SELECT 'SUCCESS: Withdrawal completed.' AS status;
END proc$$

DELIMITER ;
