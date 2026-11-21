-- ============================================================================
-- 06_isolation_levels.sql : Quick Interview Guide for Isolation Levels
-- ============================================================================

USE `banking_db`;

-- ----------------------------------------------------------------------------
-- QUICK SUMMARY FOR INTERVIEWERS:
-- 1. READ UNCOMMITTED: Allows Dirty Reads.
-- 2. READ COMMITTED  : Prevents Dirty Reads; allows Non-Repeatable Reads.
-- 3. REPEATABLE READ : (MySQL Default) Prevents Dirty & Non-Repeatable Reads.
-- 4. SERIALIZABLE    : Highest safety; acquires shared locks on all reads.
-- ----------------------------------------------------------------------------

-- Check default isolation level in MySQL:
SELECT @@GLOBAL.transaction_isolation, @@SESSION.transaction_isolation;

-- How our procedure avoids race conditions without dropping to slow SERIALIZABLE:
-- In sp_transfer_money, we use:
--     SELECT balance FROM accounts WHERE account_id IN (p_from, p_to) FOR UPDATE;
-- This places an EXCLUSIVE ROW-LEVEL LOCK on just the two accounts being updated.
-- Other users can transfer between other accounts simultaneously without waiting!
