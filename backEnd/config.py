# config.py
import os

db_config = {
    'host': os.environ.get('DB_HOST', 'localhost'),
    'port': os.environ.get('DB_PORT', '5432'),
    'database': os.environ.get('DB_NAME', 'mydb'),
    'user': os.environ.get('DB_USER', 'myuser'),
    'password': os.environ.get('DB_PASSWORD', 'mypass')
}