# 🏦 MySQL Banking System & Transaction Management Engine

A robust, interview-focused implementation of a banking transaction system built with **MySQL 8.0+** and lightweight Python tooling. 

This repository demonstrates real-world database transaction engineering: **ACID compliance**, **pessimistic row locking**, **deadlock avoidance**, **savepoints**, **idempotent transfers**, **daily limits**, and **automated audit logging**.

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Database Schema](#-database-schema)
- [Key SQL Concepts Implemented](#-key-sql-concepts-implemented)
- [Core Stored Procedure (`sp_transfer_money`)](#-core-stored-procedure-sp_transfer_money)
- [Interview Quick Reference](#-interview-quick-reference)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Test Scenarios](#-test-scenarios)

---

## 📌 Overview

Managing financial transactions requires strict guarantees that funds are neither created nor lost during concurrent execution or unexpected server failures.

This project implements:
- **Atomicity**: Complete transfer or zero mutation via `START TRANSACTION`, `COMMIT`, and `ROLLBACK`.
- **Consistency**: Hard database constraints (`CHECK (balance >= 0)`) and trigger-based validation.
- **Isolation**: Row-level locking (`SELECT ... FOR UPDATE`) preventing dirty reads and race conditions.
- **Durability**: InnoDB write-ahead redo logs and persistent double-entry audit records.
- **Defensive Engineering**: Row count assertions (`ROW_COUNT() = 1`) validating debits before credits are issued.

---

## 🏛 Database Schema

The database consists of three relational tables:

```
+--------------------+        +---------------------+        +--------------------+
|      accounts      |        |    transactions     |        |  transaction_logs  |
+--------------------+        +---------------------+        +--------------------+
| account_id (PK)    |<-------| from_account_id(FK) |        | log_id (PK)        |
| holder_name        |<-------| to_account_id (FK)  |        | account_id (FK)    |
| balance (>= 0)     |        | amount (> 0)        |        | old_balance        |
| daily_limit        |        | idempotency_key(UNI)|        | new_balance        |
| status             |        | txn_type            |        | change_amount      |
+--------------------+        | created_at          |        | logged_at          |
                              +---------------------+        +--------------------+
```

### Table Details:
1. **`accounts`**: Stores account balances, limits, and statuses (`ACTIVE` or `FROZEN`).
2. **`transactions`**: High-level ledger capturing transfer requests, amounts, and idempotency keys.
3. **`transaction_logs`**: Immutable double-entry audit trail populated automatically by database triggers whenever balances change.

---

## ⚙️ Key SQL Concepts Implemented

| Concept | SQL Syntax | Purpose |
| :--- | :--- | :--- |
| **Transaction Start** | `START TRANSACTION;` | Demarcates the boundary of atomic execution. |
| **Commit** | `COMMIT;` | Permanently confirms all balance updates and records. |
| **Rollback** | `ROLLBACK;` | Restores account states on insufficient balance or error. |
| **Recovery Point** | `SAVEPOINT debit_checkpoint;` | Intermediate checkpoint isolating debit from credit errors. |
| **Row Count Check** | `IF ROW_COUNT() = 0 THEN` | Verifies debit affected exactly one row before crediting. |
| **Pessimistic Lock** | `SELECT ... FOR UPDATE` | Locks target account rows during the transaction. |
| **Hard Constraints** | `CHECK (balance >= 0)` | Engine-level guarantee preventing negative balances. |
| **Database Triggers** | `AFTER UPDATE ON accounts` | Automatically appends entries to `transaction_logs`. |
| **Idempotency** | `UNIQUE (idempotency_key)` | Blocks replay attacks and accidental duplicate clicks. |

---

## 💻 Core Stored Procedure (`sp_transfer_money`)

The primary transaction workflow is implemented in [`sql/03_procedures.sql`](sql/03_procedures.sql):

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

    -- 1. Automatic rollback on unexpected SQL exceptions
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: Transaction rolled back.' AS status;
    END;

    -- 2. Validate input arguments
    IF p_amount <= 0 OR p_from = p_to THEN
        SELECT 'FAILED: Invalid transfer amount or self-transfer.' AS status;
        LEAVE proc;
    END IF;

    -- 3. Duplicate transaction prevention (Idempotency)
    IF p_idempotency_key IS NOT NULL THEN
        IF EXISTS (SELECT 1 FROM transactions WHERE idempotency_key = p_idempotency_key) THEN
            SELECT 'IGNORED: Duplicate transaction key detected.' AS status;
            LEAVE proc;
        END IF;
    END IF;

    -- 4. Check rolling daily transfer limit
    SELECT daily_limit INTO v_daily_limit FROM accounts WHERE account_id = p_from;
    SELECT COALESCE(SUM(amount), 0.00) INTO v_today_total
    FROM transactions
    WHERE from_account_id = p_from AND txn_type = 'TRANSFER' AND DATE(created_at) = CURDATE();

    IF (v_today_total + p_amount) > v_daily_limit THEN
        SELECT 'FAILED: Daily transfer limit exceeded.' AS status;
        LEAVE proc;
    END IF;

    -- 5. Start atomic transaction block
    START TRANSACTION;

    -- 6. Lock target rows to avoid race conditions
    SELECT balance FROM accounts WHERE account_id IN (p_from, p_to) FOR UPDATE;

    -- 7. Debit source account
    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = p_from AND balance >= p_amount;

    -- 8. Verify debit affected exactly 1 row
    IF ROW_COUNT() = 0 THEN
        ROLLBACK;
        SELECT 'FAILED: Insufficient funds or invalid source account. Rolled back.' AS status;
        LEAVE proc;
    END IF;

    -- 9. Establish intermediate recovery savepoint
    SAVEPOINT debit_checkpoint;

    -- 10. Credit destination account
    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = p_to;

    IF ROW_COUNT() = 0 THEN
        ROLLBACK TO SAVEPOINT debit_checkpoint;
        ROLLBACK;
        SELECT 'FAILED: Destination account invalid. Rolled back.' AS status;
        LEAVE proc;
    END IF;

    -- 11. Record in master transaction ledger
    INSERT INTO transactions (idempotency_key, from_account_id, to_account_id, amount, txn_type)
    VALUES (p_idempotency_key, p_from, p_to, p_amount, 'TRANSFER');

    -- 12. Commit all changes atomically
    COMMIT;
    SELECT 'SUCCESS: Funds transferred successfully.' AS status;

END proc;
```

---

## 🎤 Interview Quick Reference

When discussing this project in a technical interview:

1. **Why check `ROW_COUNT()`?**
   > *"In an UPDATE query with a conditional WHERE clause (`balance >= p_amount`), MySQL will silently succeed with 0 affected rows if balance is insufficient. Checking `ROW_COUNT() = 0` detects this and triggers a `ROLLBACK` before touching the destination account."*

2. **Why use `SELECT ... FOR UPDATE`?**
   > *"Without row locking, two simultaneous requests could read the same balance concurrently, causing a lost update race condition. `FOR UPDATE` places an exclusive lock on the involved account rows until commit."*

3. **What role does `SAVEPOINT` play?**
   > *"A savepoint creates a checkpoint after the debit operation. If crediting fails, we can roll back to the savepoint or perform diagnostic logging prior to executing a full rollback."*

4. **How are negative balances prevented?**
   > *"We use defense in depth: (1) conditional SQL update check, (2) stored procedure verification, and (3) an engine-level `CHECK (balance >= 0)` constraint."*

---

## 📁 Project Structure

```
sql_transactions/
├── .editorconfig              # Code formatting standards
├── .env.example               # Environment configuration template
├── .gitignore                 # Standard git ignore definitions
├── requirements.txt           # Python connector dependency
├── run_demo.py                # Quick demonstration entry point
├── README.md                  # Project documentation
│
├── sql/
│   ├── 01_schema.sql          # Table definitions & constraints
│   ├── 02_triggers.sql        # Audit ledger & status triggers
│   ├── 03_procedures.sql      # Transfer, deposit & withdrawal procedures
│   ├── 04_seed_data.sql       # Baseline test accounts
│   ├── 05_test_cases.sql      # SQL verification test suite
│   └── 06_isolation_levels.sql# Reference on MySQL isolation levels
│
├── python/
│   ├── db_config.py           # Database connection manager
│   ├── bank_cli.py            # Terminal interactive menu
│   ├── setup_database.py      # Automated database initializer
│   └── simulate_concurrency.py# Concurrent thread stress test
│
└── tests/
    └── test_banking.py        # Automated test suite
```

---

## 🚀 Getting Started

### Prerequisites
- MySQL Server 8.0 or higher
- Python 3.9+ (optional, for CLI and automated test suite)

### 1. Database Setup via MySQL CLI

Clone the repository and apply the scripts in order:

```bash
git clone https://github.com/your-username/sql-banking-system.git
cd sql-banking-system

mysql -u root -p < sql/01_schema.sql
mysql -u root -p < sql/02_triggers.sql
mysql -u root -p < sql/03_procedures.sql
mysql -u root -p < sql/04_seed_data.sql
```

### 2. Run Test Cases in MySQL

```bash
mysql -u root -p < sql/05_test_cases.sql
```

### 3. Optional: Running via Python

Install dependencies:
```bash
pip install -r requirements.txt
```

Run the interactive terminal interface:
```bash
python run_demo.py
```

Run the unit tests:
```bash
python -m unittest tests/test_banking.py
```

---

## 🧪 Test Scenarios

The test script [`sql/05_test_cases.sql`](sql/05_test_cases.sql) verifies:

1. **Successful Transfer**: Transfer ₹2,000 from Account 101 (₹10,000) to Account 102 (₹5,000) $\to$ Balances become ₹8,000 and ₹7,000.
2. **Insufficient Funds**: Attempting to transfer ₹15,000 from Account 101 $\to$ Immediate rollback, balances intact.
3. **Daily Limit Violation**: Transferring beyond daily limit $\to$ Rejected and rolled back.
4. **Duplicate Protection**: Resending the same `idempotency_key` $\to$ Ignored, prevents double debit.
5. **Frozen Account**: Attempting transfer to or from a frozen account $\to$ Blocked by trigger.
6. **Audit Trail**: Verifies automatic double-entry logging in `transaction_logs`.
