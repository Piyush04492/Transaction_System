"""
Database configuration settings.
"""
import os
import mysql.connector

DB_CONFIG = {
    'host': os.environ.get('MYSQL_HOST', 'localhost'),
    'port': int(os.environ.get('MYSQL_PORT', 3306)),
    'user': os.environ.get('MYSQL_USER', 'root'),
    'password': os.environ.get('MYSQL_PASSWORD', ''),
    'database': os.environ.get('MYSQL_DATABASE', 'banking_db'),
    'autocommit': True
}

def get_connection(include_db=True):
    cfg = DB_CONFIG.copy()
    if not include_db:
        cfg.pop('database', None)
    return mysql.connector.connect(**cfg)
