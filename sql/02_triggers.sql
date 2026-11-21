-- ============================================================================
-- 02_triggers.sql : Intermediate-Level Triggers for Audit & Validation
-- ============================================================================

USE `banking_db`;

DROP TRIGGER IF EXISTS `trg_log_balance_change`;
DROP TRIGGER IF EXISTS `trg_check_account_status`;

DELIMITER $$

-- 1. Audit Trigger: Automatically records every balance update into transaction_logs
CREATE TRIGGER `trg_log_balance_change`
AFTER UPDATE ON `accounts`
FOR EACH ROW
BEGIN
    IF OLD.balance != NEW.balance THEN
        INSERT INTO `transaction_logs` (`account_id`, `old_balance`, `new_balance`, `change_amount`)
        VALUES (NEW.account_id, OLD.balance, NEW.balance, (NEW.balance - OLD.balance));
    END IF;
END$$

-- 2. Validation Trigger: Blocks any transfer/update if account is FROZEN
CREATE TRIGGER `trg_check_account_status`
BEFORE UPDATE ON `accounts`
FOR EACH ROW
BEGIN
    IF OLD.status = 'FROZEN' AND OLD.balance != NEW.balance THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Operation rejected: Account is FROZEN.';
    END IF;
END$$

DELIMITER ;
