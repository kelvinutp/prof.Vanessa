import ctypes
import serial
import time
import serial.tools.list_ports
from collections import Counter
from datetime import datetime
import psycopg2
from psycopg2 import sql

# MessageBox parameters:
# 0 = OK button only
# "Supervisor program successfully opened" = message text
# "Supervisor" = title of the message box
ctypes.windll.user32.MessageBoxW(0, "Supervisor program successfully opened", "Supervisor", 0)


# Function to extract selected columns
def extract_columns(data,delimiter=';'):
    '''
    Extracts the data read from the icharger.
    Anything before the Icharger data is passed without any modification
    The data from the icharger is filtered.
    state=1 (charging, rest, discharging)
    voltaje =4
    current =5
    capacidad =14
    Args:
        data (str): string of data that has combined the data from the icharger and additional data from the program
        delimiter (str): The string used to separate the data.

    Returns:
        data (str): returns the data in string format, joined by the provided delimiter
        estado (str): returns teh current battery stage (charging, rest, dischargin, finished)
    '''
    aux=0
    aux2=False
    columns = data.split(delimiter)
    result=[]
    estado=None
    for i in columns:
        if '$' in i:
            aux2=True
        if aux2:#extrayendo data del icharger
            if aux in [1,4,5,14]:
                if aux==1: #battery stage
                    if i=='1':
                        estado='charging'
                    elif i=="2":
                        estado="discharging"
                    elif i=="4":
                        estado="rest"
                    elif i=="6":
                        estado="finished"
                    result.append(estado)
                elif aux ==4: #voltage
                    result.append(str(int(i)/1000))
                elif aux ==5: #current
                    result.append(str(int(i)/100))
                else:
                    result.append(i)
            aux+=1
        else:#records anything that is before the data from the icharger
            result.append(i)
    # print(result)
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
        cur.execute(insert_template, data)
    conn.commit()


def save_file(estado,bateria,capacidad,ciclo,folder,data,base_time,estados_pasados:list,dict_data:dict,conn=''):
    '''
    Function for saving the data file (.csv)
    By data analisis, each current state is compared to the previous four (4) states. 
    When the 5 states changes, then it's certain the battery power state has changed
    '''
    estados_pasados.append(estado.lower())
    #determine the correct battery state (charging, resting, discharging) to save data to
    if len(estados_pasados)>4:
        if all(x==estado.lower() for x in estados_pasados):
            file_name=f"{folder}/{bateria}{estado}_{capacidad}_{ciclo}.csv"
        else:
            most_common_elem, count = Counter(estados_pasados).most_common(1)[0]
            if most_common_elem=="charging" and count==3 and estado=='charging':
                ciclo+=1
            file_name=f"{folder}/{bateria}{most_common_elem}_{capacidad}_{ciclo}.csv"
        if not(file_name in dict_data):
            dict_data[file_name]=time.asctime(time.localtime())#register the time when the new file began recording
            base_time=datetime.now() #get the time when the data recording starts for the new stage
            state_file = open(file_name, "w")
            state_file.write('date;system_time;cycle_time;battery_state;voltage[V];current[mA];capacity[mAh]'+'\n')#setting column titles
            state_file.flush()
        # dict_data[file_name].append(data)
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
        if conn!='':
            aux=data.split(';')
            dataDB=[aux[0],aux[2],aux[4],aux[5],aux[6],file_name,ciclo,capacidad]
            try:
                insert_cycle_data(conn,estado,dataDB)
            except:
                print('problemas con ingresar datos en la base de datos')
    return ciclo,base_time

def monitor_serial_port(bateria,capacidad,ciclo,folder,port='COM3', baudrate=9600, log_to_file=False, timeout_seconds=60):
    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            print(f"Monitoring {port} at {baudrate} baud. Timeout after {timeout_seconds} seconds of inactivity.")
            base_time=datetime.now() #captures the time when data begins
            
            if log_to_file:
                log_file = open(f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv", "w")
                log_file.write('date;system_time;cycle_time;data starting; cycle; empty; provided voltage; voltage (mV); current (cA); battery1; battery2; battery3; battery4; battery5; battery6; unknown0; unknown1; capacity (mAh); unknown2'+'\n')#setting column titles
                log_file.flush()
            else:
                log_file = None

            last_activity_time = time.time()

            #auxiliary runtime variables
            estados_pasados=[]
            dict_data={}

            #data recording
            while True:
                timestamp = time.strftime("%Y-%m-%d; %H:%M:%S")
                if ser.in_waiting > 0:
                    data = ser.readline().decode('utf-8', errors='ignore').strip()
                    if data:
                        diff=str(abs(base_time-datetime.now()))
                        output = f"{timestamp};{diff};{data}"
                        print(output)
                        
                        data,estado=extract_columns(output)
                        if estados_pasados==['finished','finished','finished','finished']:
                            print("finished cicles \nclosing program")
                            break
                            
                        if log_to_file:
                            #original data
                            if log_file:
                                log_file.write(output + '\n')
                                log_file.flush()
                                ciclo,base_time=save_file(estado,bateria,capacidad,ciclo,data,base_time,estados_pasados,dict_data,conn=conn)
                        
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
        #show an overview of the data
        for y,z in dict_data.items():
            print(f'Timestamp: {z} \tFile:{y}')
    return

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
    
    #file naming
    confirm=False
    while not(confirm):
        bateria=input("Indique el número de batería: ")
        capacidad=input("Indique la capacidad de la bateria: ")
        ciclo=int(input("Indique el primer ciclo de la bateria (Debe ser un numero entero): "))
        print(f"El nombre del archivo se vera de la siguiente manera: {bateria}_{capacidad}_{ciclo}.csv")
        c=input("Confirme que el nombre del archivo es correcto (Y/N): ")
        if c.upper()=="Y":
            confirm=True
    
    #folder to save data
    confirm=False
    while not(confirm):
        folder=input("Inserte la direccion del folder donde desea guardar los datos: ")
        print(f'Los archivos generados se guardaran en la siguiente carpeta: {folder}')
        c=input("Confirme que la carpeta es correcta (Y/N): ")
        if c.upper()=="Y":
            confirm=True
        
    # Start reading serial data
    
    #database credential
    try:
        a="/workspaces/prof.Vanessa/monitor_Icharger/postgreDB_credential.txt"
        credentials = {}
        with open(a, "r") as file:
            for line in file:
                if "=" in line:
                    key, value = line.strip().split("=", 1)
                    credentials[key] = value
        file.close()

        conn = psycopg2.connect(host=credentials["host"], 
                            port=credentials["port"], 
                            database=credentials["database"],
                            user=credentials["user"], 
                            password=credentials["password"])
        monitor_serial_port(bateria,capacidad,ciclo,b[a],log_to_file=True,conn=conn)
    except:
        print("No hay conexiones de base de datos")
        monitor_serial_port(bateria,capacidad,ciclo,b[a],log_to_file=True)
    finally:
        input("Presione la tecla ENTER para salir")
