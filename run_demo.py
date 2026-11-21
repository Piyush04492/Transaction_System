"""
Convenience entry point to run the banking transaction demonstration.
"""
import sys
import os

# Ensure python directory is in path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), 'python')))

try:
    from bank_cli import main
    if __name__ == '__main__':
        main()
except ImportError as err:
    print(f"Error importing modules: {err}")
    print("Please install requirements using: pip install -r requirements.txt")
