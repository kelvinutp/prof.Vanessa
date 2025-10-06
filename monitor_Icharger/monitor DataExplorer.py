import ctypes
import serial
import time
import serial.tools.list_ports
from collections import Counter
from datetime import datetime
import psycopg2

# MessageBox parameters:
# 0 = OK button only
# "Supervisor program successfully opened" = message text
# "Supervisor" = title of the message box
ctypes.windll.user32.MessageBoxW(0, "Supervisor program successfully opened", "Supervisor", 0)


# Function to extract selected columns
def extract_columns(data, selected_columns,delimiter=';'):
    '''
    Extracts the intended data given the indeces in selected_columns
    Determines which is the current state type.
    '''
    columns = data.split(delimiter)  
    result=[]
    for i in selected_columns:
        if i==7: #voltage
            result.append(str(int(columns[i])/1000))
        elif i==8:#current
            result.append(str(int(columns[i])/100))
        else:
            result.append(columns[i])
    # result = [str(int(columns[i])/1000) if i==7 else columns[i] for i in selected_columns]
    if result[3]=='1':
        estado='charging'
    elif result [3]=='2':
        estado='discharging'
    elif result [3]=='4':
        estado='rest'
    elif result[3]=='6':
        estado='finished'
    result[3]=estado
    return delimiter.join(result),estado #return the data as string

def list_com_ports():
    """
    Lists all available COM ports on the system.
    Returns a list of COM port names (e.g., COM1, COM2, COM3).
    """
    print("Listing all available COM ports:")
    ports = serial.tools.list_ports.comports()  # Get a list of serial ports
    if ports:
        for index, port in enumerate(ports):
            print(f"{index}.Port: {port.device}, Description: {port.description}")
    else:
        print("No COM ports found.")
    return [port.device for port in ports]

#function to insert data into DB
def insert_cycle_data(conn, cycle: str, data: list):
    """
    Insert data into the appropriate table based on `cycle`.

    cycle: one of "charging", "rest", "discharging" (case-insensitive)
    data: list or tuple of values [date, time, voltage, current, capacity, file, cycle_number, nominal_capacity]
    """

    # Normalize the cycle string (lowercase)
    table_name = cycle.lower()
    # SQL insert template
    insert_template = sql.SQL(
        "INSERT INTO {tbl} (date, time, voltage, current, capacity, file, cycle_number, nominal_capacity) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)"
        "ON CONFLICT (date,time,file) DO NOTHING;"
    ).format(
        tbl = sql.Identifier(table_name)
    )

    # Execute with the data values
    with conn.cursor() as cur:
        # print("data insertion",data)
        cur.execute(insert_template, data)
    conn.commit()


def save_file(estado,bateria,capacidad,ciclo,data,base_time,conn=''):
    '''
    Function for saving the data file (.csv)
    By data analisis, each current state is compared to the previous four (4) states. 
    When the 5 states changes, then it's certain the battery power state has changed
    '''
    estados_pasados.append(estado)
    #determine the correct battery state (charging, resting, discharging) to save data to
    if len(estados_pasados)>4:
        if all(x==estado for x in estados_pasados):
            file_name=f"{bateria}{estado}_{capacidad}_{ciclo}.csv"
        else:
            most_common_elem, count = Counter(estados_pasados).most_common(1)[0]
            if most_common_elem=="charging" and count==3 and estado=='charging':
                ciclo+=1
            file_name=f"{bateria}{most_common_elem}_{capacidad}_{ciclo}.csv"
        if not(file_name in dict_data):
            dict_data[file_name]=[]
            base_time=time.strftime("%Y-%m-%d; %H:%M:%S") #get the time when the data recording starts for the new stage
            state_file = open(file_name, "w")
            state_file.write('date;system_time;cycle_time;battery_state;voltage[V];current[mA];capacity[mAh]'+'\n')#setting column titles
            state_file.flush()
        dict_data[file_name].append(data)
        estados_pasados.pop(0)
        
        #writing data to the specific file
        try:
            state_file = open(file_name, "a")
        except:
            print("book is already open")
        finally:
            state_file.write(data+'\n')
            state_file.flush()
        
        #writing to DB
        #formato [date, cycle_time,voltage,current,capacity,file,cycle_number,nominal_capacity]
        aux=data.split(';')
        dataDB=[aux[0],aux[2],aux[4],aux[5],aux[6],file_name,ciclo,capacidad]
        try:
            insert_cycle_data(conn,estado,dataDB)
        except:
            print('problemas con ingresar datos en la base de datos')
    return ciclo,base_time
        

def monitor_serial_port(bateria,capacidad,ciclo,port='COM3', baudrate=9600, log_to_file=False, timeout_seconds=60):
    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            print(f"Monitoring {port} at {baudrate} baud. Timeout after {timeout_seconds} seconds of inactivity.")
            base_time=time.strftime("%Y-%m-%d; %H:%M:%S") #get the time when the data recording starts
            
            if log_to_file:
                log_file = open(f"data_original_{bateria}_{capacidad}_{ciclo}.csv", "w")
                log_file.write('date;system_time;cycle_time;battery_state;voltage[V];current[mA];capacity[mAh]'+'\n')#setting column titles
                log_file.flush()
            else:
                log_file = None

            last_activity_time = time.time()

            #auxiliary runtime variables
            estados_pasados=[]
            dict_data={}
            columns_to_extract=[0,1,2,4,7,8,17]#date, system_time,cycle_time, battery_state(charing/resting/discharging),voltage(V),current(mA),capacity(mAh)

            #data recording
            while True:
                if ser.in_waiting > 0:
                    data = ser.readline().decode('utf-8', errors='ignore').strip()
                    if data:
                        timestamp = time.strftime("%Y-%m-%d; %H:%M:%S")
                        diff=str(abs(base_time-timestamp))
                        output = f"{timestamp};{diff};{data}"
                        #print(output)
                        
                        data,estado=extract_columns(output,columns_to_extract)
                        if estados_pasados==['finished','finished','finished','finished']:
                            print("finished cicles \nclosing program")
                            print(a.split(';')[0])
                            break
                            
                        if log_to_file:
                            #original data
                            if log_file:
                                log_file.write(data + '\n')
                                log_file.flush()
                                ciclo,base_time=save_file(estado,bateria,capacidad,ciclo,data,base_time,conn=conn)
                        
                        last_activity_time = time.time()

                # Check for timeout
                if time.time() - last_activity_time > timeout_seconds:
                    print(f"\nNo data received for {timeout_seconds} seconds. Exiting.")
                    if log_file:
                        log_file.write(f"[{timestamp}] fin de transmision de datos" + '\n')
                        log_file.flush()
                    break

                time.sleep(0.1)  # avoid busy loop

    except serial.SerialException as e:
        print(f"Serial error: {e}")
    except KeyboardInterrupt:
        print("\nMonitoring stopped by user.")
    finally:
        if log_file:
            log_file.close()

if __name__ == "__main__":
    # List available COM ports before starting the data reading
    b=list_com_ports()
    confirm=False
    while not(confirm):
        a=int(input("Seleccione el numero de puerto que se va a supervisar (puerto copia de VirtualSerialPort: "))
        print("ha seleccionado el puerto: ",b[a])
        c=input("Confirme que el puerto seleccionado es correcto (Y/N): ")
        if c.upper()=="Y":
            confirm=True
    confirm=False
    while not(confirm):
        bateria=input("Indique el número de batería: ")
        capacidad=input("Indique la capacidad de la bateria: ")
        ciclo=int(input("Indique el primer ciclo de la bateria (Debe ser un numero entero): "))
        print(f"El nombre del archivo se vera de la siguiente manera: {bateria}_{capacidad}_{ciclo}.csv")
        c=input("Confirme que el puerto seleccionado es correcto (Y/N): ")
        if c.upper()=="Y":
            confirm=True
    # Start reading serial data

    #database credential
    conn = psycopg2.connect(host="localhost", 
                            port=5432, 
                            database="mydb",
                            user="myuser", 
                            password="mypassword")
    
    monitor_serial_port(bateria,capacidad,ciclo,b[a],log_to_file=True,timeout_seconds=10)
    time.sleep(5)
