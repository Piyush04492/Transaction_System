"""
Banking System - Database Setup Script
Applies schema, triggers, stored procedures, and seed data.
"""
import os
import re
import sys
import subprocess
from db_config import DB_CONFIG, get_connection

SQL_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'sql'))

SQL_FILES = [
    '01_schema.sql',
    '02_triggers.sql',
    '03_procedures.sql',
    '04_seed_data.sql'
]

def run_sql_file_via_cli(file_path):
    """Attempt running SQL script via MySQL CLI client."""
    cmd = [
        'mysql',
        f"-h{DB_CONFIG['host']}",
        f"-P{DB_CONFIG['port']}",
        f"-u{DB_CONFIG['user']}",
    ]
    if DB_CONFIG['password']:
        cmd.append(f"-p{DB_CONFIG['password']}")

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            proc = subprocess.run(cmd, stdin=f, capture_output=True, text=True, check=True)
            return True, proc.stdout
    except (subprocess.SubprocessError, FileNotFoundError) as e:
        return False, str(e)

def execute_sql_file_python(conn, file_path):
    """Fallback: Execute SQL script parsing DELIMITER directives."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    cursor = conn.cursor()
    delimiter = ';'
    statement_buffer = []

    for line in content.splitlines():
        trimmed = line.strip()

        # Handle DELIMITER switch
        if trimmed.upper().startswith('DELIMITER'):
            parts = trimmed.split()
            if len(parts) >= 2:
                delimiter = parts[1]
            continue

        if not trimmed or trimmed.startswith('--') or trimmed.startswith('/*'):
            continue

        statement_buffer.append(line)

        # Check if line ends with current delimiter
        if trimmed.endswith(delimiter):
            stmt = '\n'.join(statement_buffer)
            # Strip trailing delimiter
            if delimiter != ';':
                stmt = stmt.rstrip()
                if stmt.endswith(delimiter):
                    stmt = stmt[:-len(delimiter)]
            else:
                stmt = stmt.rstrip().rstrip(';')

            stmt = stmt.strip()
            if stmt:
                try:
                    cursor.execute(stmt)
                except Exception as err:
                    print(f"Error executing statement:\n{stmt[:100]}...\nDetails: {err}")
                    raise err
            statement_buffer = []

    conn.commit()
    cursor.close()

def setup():
    print("=" * 65)
    print("  BANKING SYSTEM DATABASE INITIALIZATION")
    print("=" * 65)

    cli_available = False
    try:
        subprocess.run(['mysql', '--version'], capture_output=True, check=True)
        cli_available = True
        print("[✓] MySQL CLI tool detected.")
    except Exception:
        print("[!] MySQL CLI not found in PATH; falling back to Python connector.")

    for sql_file in SQL_FILES:
        full_path = os.path.join(SQL_DIR, sql_file)
        if not os.path.exists(full_path):
            print(f"[✗] File not found: {full_path}")
            sys.exit(1)

        print(f"Applying: {sql_file} ...", end=" ", flush=True)

        success = False
        if cli_available:
            ok, out = run_sql_file_via_cli(full_path)
            if ok:
                success = True
                print("[SUCCESS (CLI)]")
            else:
                print(f"[CLI failed: {out.strip()} - Trying Python connector] ...", end=" ")

        if not success:
            try:
                # 01_schema creates the DB, so don't select DB for first file if it doesn't exist
                conn = get_connection(include_db=(sql_file != '01_schema.sql'))
                execute_sql_file_python(conn, full_path)
                conn.close()
                print("[SUCCESS (Python)]")
            except Exception as e:
                print(f"[FAILED]\nError: {e}")
                sys.exit(1)

    print("\n[✓] Database initialization completed successfully.")
    print("=" * 65)

if __name__ == '__main__':
    setup()
