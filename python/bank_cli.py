"""
Minimal, friendly CLI to test the banking procedures.
"""
from decimal import Decimal
from db_config import get_connection

def view_accounts():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT account_id, holder_name, balance, daily_limit, status FROM accounts;")
    print("\n" + "=" * 60)
    print(f"{'ID':<6} {'Holder Name':<22} {'Balance (₹)':<14} {'Status':<10}")
    print("-" * 60)
    for row in cursor.fetchall():
        print(f"{row['account_id']:<6} {row['holder_name']:<22} {row['balance']:<14.2f} {row['status']:<10}")
    print("=" * 60)
    cursor.close()
    conn.close()

def transfer_money():
    from_acc = int(input("Source Account ID (e.g. 101): ").strip())
    to_acc = int(input("Destination Account ID (e.g. 102): ").strip())
    amount = Decimal(input("Amount (₹): ").strip())
    key = input("Transaction Key [or Enter for default]: ").strip() or None

    conn = get_connection()
    cursor = conn.cursor()
    cursor.callproc('sp_transfer_money', (from_acc, to_acc, amount, key))

    for result in cursor.stored_results():
        for row in result.fetchall():
            print("\nRESULT:", row[0])

    cursor.close()
    conn.close()

def main():
    while True:
        print("\n--- SIMPLE BANKING SYSTEM ---")
        print("1. View Accounts & Balances")
        print("2. Transfer Funds (calls sp_transfer_money)")
        print("3. Exit")
        choice = input("Select [1-3]: ").strip()
        if choice == '1':
            view_accounts()
        elif choice == '2':
            transfer_money()
        elif choice == '3':
            break

if __name__ == '__main__':
    main()
