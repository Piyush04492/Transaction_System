# 🏦 Simple Banking System (MySQL Transaction Engine)
### *Interview-Ready, Clean & Intermediate-Level Implementation*

This project demonstrates core **Database & SQL Transaction (ACID)** concepts through a practical money-transfer banking application.

---

## 🎯 Quick Code: The Core Stored Procedure (`sp_transfer_money`)

This ~70-line procedure is the heart of the project. It covers all key SQL transaction concepts:

```sql
CREATE PROCEDURE `sp_transfer_money`(
    IN p_from            INT,
    IN p_to              INT,
    IN p_amount          DECIMAL(12, 2),
    IN p_idempotency_key VARCHAR(50)
)
proc: BEGIN
    DECLARE v_today_total DECIMAL(12, 2) DEFAULT 0.00;
    DECLARE v_daily_limit DECIMAL(12, 2) DEFAULT 0.00;

    -- 1. ROLLBACK HANDLER: Reverses everything if an unexpected database error occurs
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: Transaction rolled back.' AS status;
    END;

    -- 2. BASIC VALIDATION
    IF p_amount <= 0 OR p_from = p_to THEN
        SELECT 'FAILED: Invalid transfer amount or self-transfer.' AS status;
        LEAVE proc;
    END IF;

    -- 3. DUPLICATE CHECK (Idempotency)
    IF p_idempotency_key IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM transactions WHERE idempotency_key = p_idempotency_key) THEN
            SELECT 'IGNORED: Duplicate transaction key detected.' AS status;
            LEAVE proc;
        END IF;
    END IF;

    -- 4. DAILY LIMIT CHECK
    SELECT daily_limit INTO v_daily_limit FROM accounts WHERE account_id = p_from;
    SELECT COALESCE(SUM(amount), 0.00) INTO v_today_total
    FROM transactions
    WHERE from_account_id = p_from AND txn_type = 'TRANSFER' AND DATE(created_at) = CURDATE();

    IF (v_today_total + p_amount) > v_daily_limit THEN
        SELECT 'FAILED: Daily transfer limit exceeded.' AS status;
        LEAVE proc;
    END IF;

    -- 5. START TRANSACTION: Atomic block starts here
    START TRANSACTION;

    -- 6. PESSIMISTIC LOCK: Lock rows for concurrent safety
    SELECT balance FROM accounts WHERE account_id IN (p_from, p_to) FOR UPDATE;

    -- 7. DEBIT SOURCE ACCOUNT (enforces balance >= amount)
    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = p_from AND balance >= p_amount;

    -- 8. VERIFY DEBIT AFFECTED EXACTLY 1 ROW (Crucial check!)
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;  -- Insufficient funds or account not found!
        SELECT 'FAILED: Insufficient funds. Rolled back.' AS status;
        LEAVE proc;
    END IF;

    -- 9. SAVEPOINT: Intermediate recovery point
    SAVEPOINT debit_checkpoint;

    -- 10. CREDIT DESTINATION ACCOUNT
    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_to;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK TO SAVEPOINT debit_checkpoint;
        ROLLBACK;
        SELECT 'FAILED: Destination account invalid. Rolled back.' AS status;
        LEAVE proc;
    END IF;

    -- 11. RECORD IN TRANSACTION LOG
    INSERT INTO transactions (idempotency_key, from_account_id, to_account_id, amount, txn_type)
    VALUES (p_idempotency_key, p_from, p_to, p_amount, 'TRANSFER');

    -- 12. COMMIT: Permanently save all changes
    COMMIT;
    SELECT 'SUCCESS: Transfer completed.' AS status;

END proc;
```

---

## 🎤 How to Explain This in an Interview (Concept by Concept)

| Concept | What It Does in this Code | What to Say to the Interviewer |
| :--- | :--- | :--- |
| **`START TRANSACTION`** | Begins the atomic transfer unit | *"We start an explicit transaction so debit, credit, and logging succeed together or fail together."* |
| **`COMMIT`** | Confirms successful transfer | *"Only after both debit and credit succeed do we commit the changes to disk permanently."* |
| **`ROLLBACK`** | Cancels all partial updates | *"If debit affects 0 rows (insufficient balance), we immediately trigger ROLLBACK to restore state."* |
| **`ROW_COUNT()`** | Validates rows affected | *"We don't assume the update worked: `ROW_COUNT() = 0` tells us whether the balance condition was violated."* |
| **`SAVEPOINT`** | Intermediate recovery point | *"Used after the debit step so we can revert destination errors back to a known intermediate state."* |
| **`FOR UPDATE`** | Pessimistic row lock | *"Locks the specific account rows so concurrent transfers cannot read dirty or intermediate balances."* |
| **`CHECK` Constraint** | `CHECK (balance >= 0)` | *"Database-level defense in depth to mathematically prevent negative balances."* |
| **Trigger** | `trg_log_balance_change` | *"An `AFTER UPDATE` trigger that automatically records balance changes in an audit ledger."* |
| **Idempotency** | `idempotency_key` | *"Prevents double debits if a user or network retries the same payment request."* |

---

## 📂 Project Structure

- [sql/01_schema.sql](file:///c:/Users/piyus/OneDrive/Desktop/ML/LR/sql_transactions/sql/01_schema.sql) : 3 clean tables (`accounts`, `transactions`, `transaction_logs`).
- [sql/02_triggers.sql](file:///c:/Users/piyus/OneDrive/Desktop/ML/LR/sql_transactions/sql/02_triggers.sql) : Audit logging trigger and frozen account protection trigger.
- [sql/03_procedures.sql](file:///c:/Users/piyus/OneDrive/Desktop/ML/LR/sql_transactions/sql/03_procedures.sql) : Clean, intermediate-level stored procedures (`sp_transfer_money`, `sp_deposit`, `sp_withdraw`).
- [sql/04_seed_data.sql](file:///c:/Users/piyus/OneDrive/Desktop/ML/LR/sql_transactions/sql/04_seed_data.sql) : Account A (101) with ₹10,000, Account B (102) with ₹5,000.
- [sql/05_test_cases.sql](file:///c:/Users/piyus/OneDrive/Desktop/ML/LR/sql_transactions/sql/05_test_cases.sql) : 7 clean test scenarios you can run in front of the interviewer.
- [sql/06_isolation_levels.sql](file:///c:/Users/piyus/OneDrive/Desktop/ML/LR/sql_transactions/sql/06_isolation_levels.sql) : Quick explanation of isolation levels.
- [python/bank_cli.py](file:///c:/Users/piyus/OneDrive/Desktop/ML/LR/sql_transactions/python/bank_cli.py) : Minimal, clean CLI to view accounts and run transfers.

---

## 🧪 Quick Test Run in MySQL

Execute the test suite directly in MySQL:
```sql
SOURCE sql/01_schema.sql;
SOURCE sql/02_triggers.sql;
SOURCE sql/03_procedures.sql;
SOURCE sql/04_seed_data.sql;
SOURCE sql/05_test_cases.sql;
```

Expected output for the prompt example:
```sql
CALL sp_transfer_money(101, 102, 2000.00, 'DEMO-1');
-- Returns: 'SUCCESS: Funds transferred successfully.'

SELECT account_id, balance FROM accounts WHERE account_id IN (101, 102);
-- Account 101: 8000.00
-- Account 102: 7000.00
```
