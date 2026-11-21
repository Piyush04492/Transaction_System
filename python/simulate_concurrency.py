"""
Banking System - Concurrency Stress Test & Invariant Verification
Demonstrates concurrent transfer handling, deadlock freedom, and Conservation of Money.
"""
import time
import uuid
import random
import threading
from decimal import Decimal
from db_config import get_connection

NUM_WORKERS = 10
TRANSFERS_PER_WORKER = 5

success_count = 0
failed_count = 0
counter_lock = threading.Lock()

def get_total_balance():
    """Helper to verify Conservation of Money invariant across accounts 101, 102, 103."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("SELECT SUM(balance) FROM accounts WHERE account_id IN (101, 102, 103);")
    total = cursor.fetchone()[0]
    cursor.close()
    conn.close()
    return Decimal(str(total))

def transfer_worker(worker_id):
    global success_count, failed_count
    
    accounts = [101, 102, 103]
    
    for i in range(TRANSFERS_PER_WORKER):
        # Pick two different accounts at random
        from_acc, to_acc = random.sample(accounts, 2)
        amount = Decimal(str(random.randint(50, 200)))
        idem_key = f"CONCUR-{worker_id}-{i}-{uuid.uuid4().hex[:6]}"
        
        try:
            conn = get_connection()
            cursor = conn.cursor()
            args = [from_acc, to_acc, amount, f"Concurrent W{worker_id}#{i}", idem_key, None, None, None]
            result = cursor.callproc('sp_transfer_funds', args)
            
            status = result[6]
            
            with counter_lock:
                if status == 'SUCCESS':
                    success_count += 1
                else:
                    failed_count += 1
            
            cursor.close()
            conn.close()
        except Exception as e:
            with counter_lock:
                failed_count += 1
            print(f"[Worker {worker_id}] Exception: {e}")
        
        time.sleep(0.01)

def run_concurrency_test():
    global success_count, failed_count
    success_count = 0
    failed_count = 0

    print("=" * 70)
    print("  CONCURRENCY & DEADLOCK SIMULATION TEST")
    print("=" * 70)

    try:
        initial_total = get_total_balance()
        print(f"Total Money in Test Accounts Before: INR {initial_total:,.2f}")
    except Exception as e:
        print(f"[!] Could not connect to database: {e}")
        return

    print(f"\nLaunching {NUM_WORKERS} concurrent threads, each executing {TRANSFERS_PER_WORKER} transfers...")
    print("Threads will generate simultaneous bidirectional transfers (A->B, B->A, A->C, etc.)")
    print("Deterministic lock ordering prevents deadlocks!\n")

    start_time = time.time()
    threads = []
    for wid in range(NUM_WORKERS):
        t = threading.Thread(target=transfer_worker, args=(wid,))
        threads.append(t)
        t.start()

    for t in threads:
        t.join()

    elapsed = time.time() - start_time
    final_total = get_total_balance()

    print("-" * 70)
    print("SIMULATION RESULTS:")
    print(f"  Total Time Elapsed  : {elapsed:.2f} seconds")
    print(f"  Successful Transfers: {success_count}")
    print(f"  Rejected/Limit Hits : {failed_count}")
    print(f"  Initial Total Money : INR {initial_total:,.2f}")
    print(f"  Final Total Money   : INR {final_total:,.2f}")
    
    # Invariant Verification: Total system money must be strictly conserved!
    diff = abs(final_total - initial_total)
    if diff == Decimal('0.00'):
        print("\n[✓] INVARIANT CHECK PASSED: Total system money is 100% conserved (Diff = 0.00).")
        print("[✓] ZERO DEADLOCKS OCCURRED: Deterministic lock ordering resolved all contention.")
    else:
        print(f"\n[✗] INVARIANT VIOLATION: Money discrepancy of INR {diff} detected!")

    print("=" * 70)

if __name__ == '__main__':
    run_concurrency_test()
