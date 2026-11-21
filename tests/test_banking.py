"""
Automated unit tests for sp_transfer_money
"""
import unittest
from decimal import Decimal
import sys
import os

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'python')))
from db_config import get_connection

class TestBanking(unittest.TestCase):
    def setUp(self):
        self.conn = get_connection()
        self.cursor = self.conn.cursor(dictionary=True)

    def tearDown(self):
        self.cursor.close()
        self.conn.close()

    def get_balance(self, acc_id):
        self.cursor.execute("SELECT balance FROM accounts WHERE account_id = %s", (acc_id,))
        row = self.cursor.fetchone()
        return Decimal(str(row['balance'])) if row else None

    def test_transfer_success(self):
        # Reset 101 to 10000, 102 to 5000
        self.cursor.execute("UPDATE accounts SET balance = 10000.00 WHERE account_id = 101;")
        self.cursor.execute("UPDATE accounts SET balance = 5000.00 WHERE account_id = 102;")
        self.conn.commit()

        cursor = self.conn.cursor()
        cursor.callproc('sp_transfer_money', (101, 102, Decimal("2000.00"), "UNIT-KEY-1"))
        cursor.close()

        self.assertEqual(self.get_balance(101), Decimal("8000.00"))
        self.assertEqual(self.get_balance(102), Decimal("7000.00"))

    def test_insufficient_funds_rollback(self):
        bal_a_before = self.get_balance(101)
        bal_b_before = self.get_balance(102)

        cursor = self.conn.cursor()
        cursor.callproc('sp_transfer_money', (101, 102, Decimal("50000.00"), "UNIT-KEY-2"))
        cursor.close()

        # Balances must be unchanged
        self.assertEqual(self.get_balance(101), bal_a_before)
        self.assertEqual(self.get_balance(102), bal_b_before)

if __name__ == '__main__':
    unittest.main()
