import os
import csv
from pathlib import Path
import re
import psycopg2
from psycopg2 import sql

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
        raise FileNotFoundError(f"{file} not found.")
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
        if "finish" in file.lower() or 'original' in file.lower():
            return #not useful data
        file_name=file.lower().split('/')
        # print(file_name)
        match = pattern.search(file_name[-1])
        # print(match)
        if not match:
            cycle="unknown"
        kw = match.group(0).lower()
        if kw.startswith("dis"):
            cycle= "discharging"
        elif kw == "rest":
            cycle= "rest"
        else:
            cycle= "charging"
    
    #extract the data in the desired order
        aux=0
        print(headings)
        
        while True: #extracting the remaining data
            line=f.readline().strip()
            if line:
                data=line.split(';')
                db_data=[data[a] for a in order.values()]
                if 'date' not in order:
                    db_data.insert(0,date.group(0))
                db_data.append(file_name[-1])
                insert_cycle_data(conn, cycle,db_data)
                aux+=1
            else:
                break #finished reading data

def create_tables_and_triggers(conn):
    commands = [
        # Create base tables
        """
        CREATE TABLE IF NOT EXISTS charging (
            date DATE NOT NULL,
            time TIME NOT NULL,
            voltage DOUBLE PRECISION,
            current DOUBLE PRECISION,
            capacity DOUBLE PRECISION,
            file TEXT NOT NULL,
            PRIMARY KEY (date, time, file)
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS rest (
            date DATE NOT NULL,
            time TIME NOT NULL,
            voltage DOUBLE PRECISION,
            current DOUBLE PRECISION,
            capacity DOUBLE PRECISION,
            file TEXT NOT NULL,
            PRIMARY KEY (date, time, file)
        );
        """,
        """
        CREATE TABLE IF NOT EXISTS discharging (
            date DATE NOT NULL,
            time TIME NOT NULL,
            voltage DOUBLE PRECISION,
            current DOUBLE PRECISION,
            capacity DOUBLE PRECISION,
            file TEXT NOT NULL,
            PRIMARY KEY (date, time, file)
        );
        """,
        # Create all_data
        """
        CREATE TABLE IF NOT EXISTS all_data (
            date DATE NOT NULL,
            time TIME NOT NULL,
            voltage DOUBLE PRECISION,
            current DOUBLE PRECISION,
            capacity DOUBLE PRECISION,
            mode VARCHAR(20) NOT NULL,
            file TEXT NOT NULL,
            PRIMARY KEY (date, time, mode, file)
        );
        """,
        # Trigger for charging → all_data
        """
        CREATE OR REPLACE FUNCTION trg_after_insert_charging()
        RETURNS TRIGGER AS $$
        BEGIN
            INSERT INTO all_data(date, time, voltage, current, capacity, mode, file)
            VALUES (NEW.date, NEW.time, NEW.voltage, NEW.current, NEW.capacity, 'charging', NEW.file)
            ON CONFLICT (date, time, mode, file) DO NOTHING;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """,
        """
        DROP TRIGGER IF EXISTS after_insert_charging ON charging;
        CREATE TRIGGER after_insert_charging
        AFTER INSERT ON charging
        FOR EACH ROW
        EXECUTE FUNCTION trg_after_insert_charging();
        """,
        # Trigger for rest → all_data
        """
        CREATE OR REPLACE FUNCTION trg_after_insert_rest()
        RETURNS TRIGGER AS $$
        BEGIN
            INSERT INTO all_data(date, time, voltage, current, capacity, mode, file)
            VALUES (NEW.date, NEW.time, NEW.voltage, NEW.current, NEW.capacity, 'rest', NEW.file)
            ON CONFLICT (date, time, mode, file) DO NOTHING;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """,
        """
        DROP TRIGGER IF EXISTS after_insert_rest ON rest;
        CREATE TRIGGER after_insert_rest
        AFTER INSERT ON rest
        FOR EACH ROW
        EXECUTE FUNCTION trg_after_insert_rest();
        """,
        # Trigger for discharging → all_data
        """
        CREATE OR REPLACE FUNCTION trg_after_insert_discharging()
        RETURNS TRIGGER AS $$
        BEGIN
            INSERT INTO all_data(date, time, voltage, current, capacity, mode, file)
            VALUES (NEW.date, NEW.time, NEW.voltage, NEW.current, NEW.capacity, 'discharging', NEW.file)
            ON CONFLICT (date, time, mode, file) DO NOTHING;
            RETURN NEW;
        END;
        $$ LANGUAGE plpgsql;
        """,
        """
        DROP TRIGGER IF EXISTS after_insert_discharging ON discharging;
        CREATE TRIGGER after_insert_discharging
        AFTER INSERT ON discharging
        FOR EACH ROW
        EXECUTE FUNCTION trg_after_insert_discharging();
        """
    ]

    cur = conn.cursor()
    for cmd in commands:
        cur.execute(cmd)
    conn.commit()
    
def insert_cycle_data(conn, cycle: str, data: list):
    """
    Insert data into the appropriate table based on `cycle`.

    cycle: one of "charging", "rest", "discharging" (case-insensitive)
    data: list or tuple of values [date, time, voltage, current, capacity, file]
    """

    # Normalize the cycle string (lowercase)
    table_name = cycle.lower()
    # SQL insert template
    insert_template = sql.SQL(
        "INSERT INTO {tbl} (date, time, voltage, current, capacity, file) "
        "VALUES (%s, %s, %s, %s, %s, %s)"
        "ON CONFLICT (date,time,file) DO NOTHING;"
    ).format(
        tbl = sql.Identifier(table_name)
    )

    # Execute with the data values
    with conn.cursor() as cur:
        # print("data insertion",data)
        cur.execute(insert_template, data)
    conn.commit()


# ---- Run the script ----
if __name__ == '__main__':
    #pendientes revisar
    conn = psycopg2.connect(host="localhost", port=5432, database="mydb",
                            user="myuser", 
                            password="mypassword")
    try:
        create_tables_and_triggers(conn)
        print("Tables and triggers created.")
    except Exception as e:
        print("Error:", e)
    finally:
        conn.close()
    CSV_FILE_PATH=input("Ingrese la ruta del archivo a revisar: ")
    txt_files = [os.path.join(CSV_FILE_PATH, f) for f in os.listdir(CSV_FILE_PATH) if f.endswith('.csv') and os.path.isfile(os.path.join(CSV_FILE_PATH, f))]
    for a in txt_files:
        b=get_column_title(a)
  
