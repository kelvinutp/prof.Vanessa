import os
import csv
from pathlib import Path
import re


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

def order_columns(header_row):
    a=header_row.lower().split(';')
    expected_columns=['date','time','voltage','current','capacity']
    file_column_order={} #key=battery parameter, value=column number
    for aux in expected_columns:
     	index=0
     	while index<len(a):
     		if aux in a[index]:
     			file_column_order[aux]=index
     			break
     		index+=1
    return file_column_order

#getting the correct row. Not always the first row has the column titles. This may be found in the first five (5) rows
def get_column_title(file):
    csv_path = Path(file)
    if not csv_path.exists():
        raise FileNotFoundError(f"{csv_file_path} not found.")
    with csv_path.open('r', newline='', encoding='utf-8') as f:
        aux=False
        count=0
        while not(aux):
            line=f.readline()
            if line.count(';')>=3:
                aux=True
        #order the columns (date, time, voltage, current, capacity)
        order=order_columns(line.strip())
        headings=[a for a in order.keys()]
        if 'date' not in order:
            try:
                date= re.search(r'\d{4}-\d{2}-\d{2}', file)
                headings.insert(0,'date')
            except ValueError:
                pass
        
        #determine if the file is for charging, resting or discharging (from the file title)
        # Regex: look for “charg” or “discharg” or “rest”, case-insensitive
        pattern = re.compile(r"(?i)(?:dis)?charg|rest")
        match = pattern.search(file.lower())
        if not match:
            cycle="unknown"
        kw = match.group(0).lower()
        if kw.startswith("dis"):
            cycle= "discharge"
        elif kw == "rest":
            cycle= "rest"
        else:
            cycle= "charge"
    
        print (cycle)
    
        #extract the data in the desired order
        aux=0
        print(headings)
        while aux<10: #extracting the remaining data
            line=f.readline().strip()
            data=line.split(';')
            db_data=[data[a] for a in order.values()]
            if 'date' not in order:
                db_data.insert(0,date.group(0))
            print(db_data)
            aux+=1

    
# ---- Run the script ----
if __name__ == '__main__':
    CSV_FILE_PATH=input("Ingrese la ruta del archivo a revisar: ")
    txt_files = [f for f in os.listdir(CSV_FILE_PATH) if f.endswith('.csv') and os.path.isfile(os.path.join(CSV_FILE_PATH, f))]
    for a in txt_files:
        b=get_column_title(a)
  
