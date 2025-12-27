#GUI libraries
import tkinter as tk
from tkinter import ttk

#multiple process libraries
import threading
import queue
import sys

#time libraries
import time
from datetime import datetime

#connection to COM ports
import serial.tools.list_ports #to list com ports
import serial #to establish communication with the selected com port
from collections import Counter

#SQL connections
import psycopg2
from psycopg2 import sql

import os
# Global variables
user_inputs = {}
user_inputs['COM port']='COM4'
user_inputs['Baud rate']=9600
user_inputs['Guardar datos']='False'
user_inputs['Bateria']='1'
user_inputs['Capacidad nominal']='test1'
user_inputs['Ciclo']='2'
user_inputs['Ruta de folder']=''#r'C:\Users\user\Desktop\data\new tryout'
user_inputs['dB credential file']=''#r'C:\Users\user\Desktop\data\db credentials.txt'

console_queue = queue.Queue()
app_running = True
main_script_done = False
second_window = None
confirmation =0

#Redirect print to queue
class QueuePrinter:
    def write(self, msg):
        if msg.strip() != '':
            console_queue.put(msg+'\n')

    def flush(self):
        pass

sys.stdout = QueuePrinter()

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

# Function to extract selected columns
def extract_columns(data,delimiter=';',data_history:list=[]):
    """
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
    """
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
        elif i.strip()!=None:#records anything that is before the data from the icharger
            result.append(i.strip())
    return delimiter.join(result), estado #return the data as string

def insert_cycle_data(conn, cycle: str, data: list):
    """Saves data into the database and corresponding table

    Args:
        conn (_type_): postgreDB credentials
        cycle (str): battery cycle stage (charging, discharging, rest)
        data (list): Data to save. Format [date, cycle_time,voltage,current,capacity,file,cycle_number,nominal_capacity]
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
    return

def save_file(mode:int, naming:list, raw_data:str|list='', last_duration:float=0, stages_history:list=[], conn=None):
    
    bateria=naming[0]
    capacidad=naming[1]
    ciclo=naming[2]
    folder=naming[3]

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
            
            #trying to write to database
            if not(conn is None):
                aux=modified_data.split(';')
                dataDB=[aux[0],aux[2],aux[5],aux[6],aux[7],file_name,ciclo,capacidad]

                try:
                    insert_cycle_data(conn,estados,dataDB)
                except:
                    print('problemas con ingresar datos en la base de datos')
            state_file.write(modified_data+'\n')
            state_file.flush()
            state_file.close()
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
            
            # base_time=time.time() #captures the time when data begins
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


##********************************************
##GUI
#*********************************************


# First window to get user input
def open_input_window(com_ports:list):
    aux=[x for x in user_inputs.keys()]
    global confirmation

    #capture the inputs
    def on_submit():
        global confirmation
        if confirmation>0:
            user_inputs['COM port'] = dropdown_var.get()
            user_inputs["Guardar datos"] = selected_value.get()
            for y in aux[3:]:                
                user_inputs[y]=user_inputs[y].get()
                if y=='Ruta de folder' and len(user_inputs[y])==0:#if no folder is provided, getting current working directory
                    user_inputs[y]=os.getcwd()
            for y in aux:
                print(f'Data: {y}, Value:{user_inputs[y]}, type:{type(user_inputs[y])}')
            root.destroy()
        else:
            confirmation+=1

    #show the interface
    root = tk.Tk()
    root.title("Input Window")
    
    #creating dropdown to choose com ports
    ttk.Label(root, text="COM port:").grid(row=0, column=0, pady=5)
    dropdown_var = tk.StringVar()
    dropdown = ttk.Combobox(root, textvariable=dropdown_var)
    dropdown['values'] = com_ports
    dropdown.grid(row=0, column=1, pady=5)

    #Radio Button to save file
    selected_value = tk.StringVar(value="True")  # default is "True"
    ttk.Label(root, text="Guardar datos: ").grid(row=1, column=0, pady=5)
    true_button = ttk.Radiobutton(root, text="Si guardar datos", variable=selected_value, value="True")
    false_button = ttk.Radiobutton(root, text="No guardar datos", variable=selected_value, value="False")
    true_button.grid(row=1, column=1, pady=5)
    false_button.grid(row=1, column=2, pady=5)

    #creates input boxes    
    for i,j in enumerate(aux[3:]):
        ttk.Label(root, text=f"{j}: ").grid(row=i+2, column=0, pady=5)
        entry = tk.Entry(root)
        entry.grid(row=i+2, column=1, pady=5)
        user_inputs[j]=entry
    
    submit_button = ttk.Button(root, text="Presionar dos (2) veces para iniciar", command=on_submit)
    submit_button.grid(row=len(user_inputs.keys())+2, column=0, columnspan=2)

    root.mainloop()

# Second window to display input and terminal output
def open_second_window():
    global second_window
    second_window = tk.Tk()
    second_window.title("Status Window")

    top_frame = ttk.Frame(second_window)
    top_frame.pack(side=tk.TOP, fill=tk.X)

    for key, value in user_inputs.items():
        ttk.Label(top_frame, text=f"{key}: {value}").pack(anchor='w')

    terminal_frame = ttk.Frame(second_window)
    terminal_frame.pack(side=tk.TOP, fill=tk.BOTH, expand=True)

    text_area = tk.Text(terminal_frame, height=20, wrap='word', state='disabled')
    text_area.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)

    scrollbar = ttk.Scrollbar(terminal_frame, command=text_area.yview)
    scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
    text_area['yscrollcommand'] = scrollbar.set

    def update_terminal():
        while not console_queue.empty():
            msg = console_queue.get_nowait()
            text_area.config(state='normal')
            text_area.insert(tk.END, msg)
            text_area.see(tk.END)
            text_area.config(state='disabled')
        if app_running or not main_script_done:
            second_window.after(100, update_terminal)
        elif main_script_done:
            text_area.config(state='normal')
            text_area.insert(tk.END, "\n[Program Finished]")
            text_area.config(state='disabled')

    def on_close():
        second_window.destroy()
        print("Closing windows")


    second_window.protocol("WM_DELETE_WINDOW", on_close)
    update_terminal()
    second_window.mainloop()

# Simulate main script logic (replace with actual COM logic)
def run_main_script():
    global main_script_done
    
    #trying to read database credential
    try:
        a=user_inputs['dB credential file']
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
            ciclo=user_inputs['Ciclo'],
            naming=[user_inputs['Ruta de folder'],user_inputs['Bateria'],user_inputs['Capacidad nominal'],user_inputs['Ciclo']],
            port=user_inputs['COM port'],
            baudrate=9600,
            timeout_seconds=10,
            log_to_file=eval(user_inputs["Guardar datos"].capitalize()),
            conn=conn
        )
    print("Main script finished.")
    time.sleep(10)
    main_script_done = True    
    if not second_window:
        threading.Thread(target=open_second_window, daemon=True).start()

# Launch
if __name__ == '__main__':
    open_input_window(list_com_ports())
    threading.Thread(target=open_second_window, daemon=True).start()
    threading.Thread(target=run_main_script, daemon=True).start()
    # run_main_script()

    # Keep the main thread alive
    while not main_script_done:
        time.sleep(1)
    print("done")
