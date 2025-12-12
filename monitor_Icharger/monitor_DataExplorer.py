import ctypes
import serial
import time
import serial.tools.list_ports
from collections import Counter
from datetime import datetime
import psycopg2
from psycopg2 import sql
import os

# MessageBox parameters:
# 0 = OK button only
# "Supervisor program successfully opened" = message text
# "Supervisor" = title of the message box
# ctypes.windll.user32.MessageBoxW(0, "Supervisor program successfully opened", "Supervisor", 0)


# Function to extract selected columns
def extract_columns(data,delimiter=';',data_history:list=[]):
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
    Returns
        -------
        data (str)
            returns the data in string format, joined by the provided delimiter.
        estado (str)
            returns the current battery stage (charging, rest, dischargin, finished)
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
                    most_common_elem, count = Counter(data_history).most_common(1)[0]
                    if most_common_elem!=i.strip():
                        i=most_common_elem
                    if i.strip()=='1':
                        estado='charging'
                    elif i.strip()=="2":
                        estado="discharging"
                    elif i.strip()=="4":
                        estado="rest"
                    elif i.strip()=="6":
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

# def save_file(estado:str,bateria:str,capacidad:str,ciclo:str,folder:str,data:str,base_time:datetime,stages_history:list,data_history:dict,conn=None):
def save_file(mode:int, naming:list, raw_data:str|list='', last_duration:float=0, stages_history:list=[], conn=None):
    
    folder=naming[0]
    bateria=naming[1]
    capacidad=naming[2]
    ciclo=naming[3]

    if mode==1: #creating raw data file
        log_file = open(f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv", "w")
        log_file.write('date;system_time;cycle_time;cycle_number;data starting;cycle;empty;provided voltage;voltage (mV);current (cA);battery1;battery2;battery3;battery4;battery5;battery6;unknown0;unknown1;capacity (mAh);unknown2'+'\n')#setting column titles
        log_file.flush()
        log_file.close()
        return
    
    elif mode==2: #saving data to file from string raw data
        log_file = open(f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv", "a")
        log_file.write(raw_data + '\n')
        log_file.flush()
        log_file.close()

        ciclo=raw_data.split('$')[0].split(';')[-2]
        # #process data to save into independent file and postgredb
        cicle_time=0
        [cicle_time:= cicle_time+float(x) for x in raw_data.split('$')[0].split(';')[-3].split(':')]
        modified_data,estados=extract_columns(raw_data,data_history=stages_history)

        # #determine the correct battery state (charging, resting, discharging) to save data to
        file_name=f"{folder}\\{bateria}{estados}_{capacidad}_{ciclo}.csv"
        if last_duration==0 or last_duration>cicle_time: #new file
            state_file = open(file_name, "w")
            state_file.write('date;system_time;cycle_time;cycle_number;battery_state;voltage[V];current[mA];capacity[mAh]'+'\n')#setting column titles

        # #writing data to the specific file
        try:
            state_file = open(file_name, "a")
        except:
            print("book is already open")
        finally:
            state_file.write(modified_data+'\n')
            state_file.flush()
            state_file.close()
       
            #writing to DB
            #formato [date, cycle_time,voltage,current,capacity,file,cycle_number,nominal_capacity]            
            if not(conn is None):
                aux=modified_data.split(';')
                dataDB=[aux[0],aux[2],aux[5],aux[6],aux[7],file_name,ciclo,capacidad]

                try:
                    insert_cycle_data(conn,estados,dataDB)
                except:
                    print('problemas con ingresar datos en la base de datos')
        return
    
    elif mode==3:#saving data to file from list raw data
        #writing to raw file data
        log_file = open(f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv", "a")

        aux=aux1=0
        for a in raw_data:
            #writing to raw data file 
            log_file.write(a + '\n')
            log_file.flush()

            #writing to individual files
            aux=0
            [aux:=aux+float(x) for x in a.split('$')[0].split(';')[-3].split(':')]
            ciclo=a.split('$')[0].split(';')[-2]
            stages_history.append(a.split('$')[1].split(';')[1])
            modified_data,estados=extract_columns(a,data_history=stages_history[-5:])
            file_name=f"{folder}\\{bateria}{estados}_{capacidad}_{ciclo}.csv"

            if aux1>aux: #new cycle time
                aux1=0
                #creating new file
                state_file = open(file_name, "w")
                state_file.write('date;system_time;cycle_time;cycle_number;battery_state;voltage[V];current[mA];capacity[mAh]'+'\n')#setting column titles
            else:
                aux1=aux
                #writing data to existing file 
                file_name=f"{folder}\\{bateria}{estados}_{capacidad}_{ciclo}.csv"
                state_file = open(file_name, "a")
            state_file.write(modified_data+'\n')
            state_file.flush()
            state_file.close()
            
            #writing to DB
            #formato [date, cycle_time,voltage,current,capacity,file,cycle_number,nominal_capacity]            
            if not(conn is None):
                aux=modified_data.split(';')
                dataDB=[aux[0],aux[2],aux[5],aux[6],aux[7],file_name,ciclo,capacidad]

                try:
                    insert_cycle_data(conn,estados,dataDB)
                except:
                    print('problemas con ingresar datos en la base de datos')

        log_file.close()
        return
            
def monitor_serial_port(ciclo:str|int, naming:list, port='COM3', baudrate=9600,timeout_seconds=60, log_to_file=False, conn=None):
    """Only Reads the data from Serial COM port and saves it into a local postgreDB and CSV files

    Args:
        naming(list): items needed to create the file
        port (str, optional): COM port from which to read the data. Defaults to 'COM3'.
        baudrate (int, optional): baudrate at which to read data from com port. Defaults to 9600.
        log_to_file (bool, optional): Determines if data is to be saved in a file. Defaults to False.
        timeout_seconds (int, optional): _description_. Defaults to 60.
        conn (_type_, optional): Connection to postgreDB credentials. Defaults to None.
    """    

    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            print(f"monitor_serial_port function:\nMonitoring {port} at {baudrate} baud. Timeout after {timeout_seconds} seconds of inactivity.")
            
            base_time=datetime.now() #captures the time when data begins
            last_activity_time = time.time()
            cycle_history=[]
            stage=''
            duration=0

            if isinstance(ciclo,int):
                manipulable_cycle=ciclo #variable for operating during runtime
            else:
                manipulable_cycle=int(ciclo) #variable for operating during runtime

            if log_to_file:#proceed to create the files to save raw data.
                save_file(mode=1,naming=naming)
                print("Creating raw data file")
                temp_memory=[]
            #data recording
            while True:
            # for i in range(100): #for testing purposes
                timestamp = time.strftime("%Y-%m-%d;%H:%M:%S")
                print(f'{timestamp},{ser.in_waiting}')
                if ser.in_waiting >0:
                    data = ser.readline().decode('utf-8', errors='ignore').strip()
                    if data:
                        diff=abs(base_time-datetime.now())
                        cycle_history.append(data.split(';')[1])
                        output = f"{timestamp};{diff};{manipulable_cycle};{data}"
                        print(output)
                        if cycle_history[-5:]==['4','4','1','1','1']:
                            manipulable_cycle+=1
                            base_time=datetime.now()
                        elif cycle_history[-5:]==['6','6','6','6','6']: #if received this information, it's finished 
                            break

                        try: #trying to save the data
                            stage=cycle_history[-5:]
                            if log_to_file:
                                save_file(mode=2,raw_data=output, 
                                          last_duration=duration, 
                                          stages_history=stage, 
                                          naming=naming, conn=conn)
                            duration=0
                            [duration:= duration+float(x) for x in output.split('$')[0].split(';')[-3].split(':')]
                        except PermissionError: #the CSV file is opened by another program
                            temp_memory.append(output)
                        last_activity_time = time.time()
                else:
                    print("No data received")
                # Check for timeout
                if time.time() - last_activity_time > timeout_seconds:
                    print(f"\nNo data received for {timeout_seconds} seconds. Exiting.")
                    break
                time.sleep(0.1)  # avoid busy loop

    except serial.SerialException as e:
        print(f"Serial error: {e}")
    except KeyboardInterrupt:
        print("\nMonitoring stopped by user.")
    finally:
        print("Done monitoring Serial COM port")
        print("Last cycle: ",manipulable_cycle)
        if log_to_file:
            try:
                if len(temp_memory)>0:
                    print("There was data not saved because of Excel opened")
                    save_file(mode=3,raw_data=temp_memory, naming=naming ,conn=conn)
            except:
                print("No temp memory stored")
    return

if __name__ == "__main__":
    # List available COM ports before starting the data reading
    b=list_com_ports()
    confirm=False
    while not(confirm):
        port=int(input("Seleccione el numero de puerto que se va a supervisar (puerto copia de VirtualSerialPort: "))
        print("ha seleccionado el puerto: ",b[port])
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
        folder=input("Inserte la direccion del folder donde desea guardar los datos (sino se inserta direccion, se guardaran en la carpeta actual): ")
        if folder=='':
            folder=os.getcwd()
        print(f'Los archivos generados se guardaran en la siguiente carpeta: {folder}')
        c=input("Confirme que la carpeta es correcta (Y/N): ")
        if c.upper()=="Y":
            confirm=True
        
    # Start reading serial data

    #trying to read database credential
    try:
        a=input("Ingrese la direccion del archivo donde guarda las credenciales de base de datos: ")
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
        print("db credentials")
    except:
        conn=None
        print("no db credentials")
    finally:
        #reading COM port data
        monitor_serial_port(
            ciclo=ciclo,
            naming=[folder,bateria,capacidad,ciclo],
            port=b[port],
            baudrate=9600,
            timeout_seconds=10,
            log_to_file=True,
            conn=conn
        )
        input("Presione la tecla ENTER para salir")
