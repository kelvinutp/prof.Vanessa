import csv
import psycopg2
import os
from datetime import datetime

# ---- Configuration ----
DB_CONFIG = {
    'dbname': 'your_db',
    'user': 'your_user',
    'password': 'your_password',
    'host': 'localhost',
    'port': 5432  # Default PostgreSQL port
}

TABLE_NAME = 'sensor_data'

# ---- Function to insert data ----
def insert_data_from_csv(csv_path):
    try:
        # Extract just the file name (not full path)
        file_name = os.path.basename(csv_path)

        # Connect to PostgreSQL
        conn = psycopg2.connect(**DB_CONFIG)
        cursor = conn.cursor()

        with open(csv_path, 'r', newline='') as csvfile:
            reader = csv.DictReader(csvfile)

            rows = [
                (
                    row['timestamp'],     # assumes timestamp format is compatible
                    row['sensor_id'],
                    float(row['value1']),
                    float(row['value2']),
                    float(row['value3']),
                    float(row['value4']),
                    float(row['value5']),
                    float(row['value6']),
                    float(row['value7']),
                    float(row['value8']),
                    file_name             # new column: source_file
                )
                for row in reader
            ]

        insert_query = f"""
            INSERT INTO {TABLE_NAME} (
                timestamp, sensor_id,
                value1, value2, value3, value4, value5, value6, value7, value8,
                source_file
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """

        cursor.executemany(insert_query, rows)
        conn.commit()

        print(f"✅ Successfully inserted {len(rows)} rows from '{file_name}' into '{TABLE_NAME}'.")

    except Exception as e:
        print(f"❌ Error: {e}")
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

# ---- Run the script ----
if __name__ == '__main__':
  CSV_FILE_PATH=input("Ingrese la ruta del archivo a revisar: ")
  insert_data_from_csv(CSV_FILE_PATH)
  
