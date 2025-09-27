import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

# ---- Configuration ----
POSTGRES_ADMIN = {
    'dbname': 'postgres',         # connect to default 'postgres' database
    'user': 'your_admin_user',
    'password': 'your_admin_password',
    'host': 'localhost',
    'port': 5432
}

NEW_DB_NAME = 'your_new_db_name'
NEW_TABLE_NAME = 'sensor_data'

# ---- SQL to create table ----
CREATE_TABLE_SQL = f"""
CREATE TABLE IF NOT EXISTS {NEW_TABLE_NAME} (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ NOT NULL,
    sensor_id TEXT NOT NULL,
    value1 DOUBLE PRECISION,
    value2 DOUBLE PRECISION,
    value3 DOUBLE PRECISION,
    value4 DOUBLE PRECISION,
    value5 DOUBLE PRECISION,
    value6 DOUBLE PRECISION,
    value7 DOUBLE PRECISION,
    value8 DOUBLE PRECISION,
    source_file TEXT
);
"""

# ---- Step 1: Create Database if not exists ----
def create_database():
    try:
        # Connect to the default database
        conn = psycopg2.connect(**POSTGRES_ADMIN)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)  # Needed to CREATE DATABASE
        cursor = conn.cursor()

        # Check if DB exists
        cursor.execute("SELECT 1 FROM pg_database WHERE datname = %s", (NEW_DB_NAME,))
        exists = cursor.fetchone()

        if not exists:
            cursor.execute(f"CREATE DATABASE {NEW_DB_NAME}")
            print(f"✅ Database '{NEW_DB_NAME}' created.")
        else:
            print(f"ℹ️ Database '{NEW_DB_NAME}' already exists.")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Error creating database: {e}")

# ---- Step 2: Create Table in New Database ----
def create_table():
    try:
        # Now connect to the new database
        db_conn_config = POSTGRES_ADMIN.copy()
        db_conn_config['dbname'] = NEW_DB_NAME

        conn = psycopg2.connect(**db_conn_config)
        cursor = conn.cursor()

        cursor.execute(CREATE_TABLE_SQL)
        conn.commit()

        print(f"✅ Table '{NEW_TABLE_NAME}' created in database '{NEW_DB_NAME}'.")

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Error creating table: {e}")

# ---- Run Steps ----
if __name__ == '__main__':
    create_database()
    create_table()
