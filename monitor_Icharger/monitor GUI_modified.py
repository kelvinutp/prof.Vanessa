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

# #Redirect print to queue
# class QueuePrinter:
#     def write(self, msg):
#         if msg.strip() != '':
#             console_queue.put(msg+'\n')

#     def flush(self):
#         pass

# sys.stdout = QueuePrinter()

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
def extract_columns(data,delimiter=';'):
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

    Returns:
        estado (str): returns the current battery stage (charging, rest, dischargin, finished)
        data (str): returns the data in string format, joined by the provided delimiter.
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


# def save_file(estado:str,bateria:str,capacidad:str,ciclo:str,folder:str,data:str,base_time:datetime,stages_history:list,data_history:dict,conn=None):
def save_file(mode:int, raw_data:str|list, ciclo:int, folder:str, bateria:str, capacidad:str,conn=None):
    
    if mode==1: #creating raw data file
        print("creating raw data file")
        log_file = open(f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv", "w")
        log_file.write('date;system_time;cycle_time;cycle_number;data starting; cycle; empty; provided voltage; voltage (mV); current (cA); battery1; battery2; battery3; battery4; battery5; battery6; unknown0; unknown1; capacity (mAh); unknown2'+'\n')#setting column titles
        log_file.flush()
        stages_history=[]
        data_history={}

        return
    
    elif mode==2: #saving data to file
        print("saving data to file")
        if isinstance(raw_data,str):
            #save raw data
            log_file.write(raw_data + '\n')
            log_file.flush()

        #process data to save into independent file and postgredb
        modified_data,estados=extract_columns(raw_data)
        stages_history.append(estados)

        #determine the correct battery state (charging, resting, discharging) to save data to
        if len(stages_history)>4:
            if all(x==estados for x in stages_history):
                file_name=f"{folder}\\{bateria}{estados}_{capacidad}_{ciclo}.csv"
            else:
                most_common_elem, count = Counter(stages_history).most_common(1)[0]
                if most_common_elem=="charging" and count==3 and estados=='charging':
                    ciclo+=1
                file_name=f"{folder}\\{bateria}{most_common_elem}_{capacidad}_{ciclo}.csv"
            if not(file_name in data_history):
                data_history[file_name]=time.asctime(time.localtime())#register the time when the new file began recording
                base_time=time.time() #get the time when the data recording starts for the new stage
                state_file = open(file_name, "w")
                state_file.write('date;system_time;cycle_time;battery_state;voltage[V];current[mA];capacity[mAh]'+'\n')#setting column titles
                state_file.flush()
            stages_history.pop(0)
        
            #writing data to the specific file
            try:
                state_file = open(file_name, "a")
            except:
                print("book is already open")
            finally:
                state_file.write(modified_data+'\n')
                state_file.flush()
        return ciclo, base_time
    #     #writing to DB
    #     #formato [date, cycle_time,voltage,current,capacity,file,cycle_number,nominal_capacity]
        if not(conn is None):
            aux=modified_data.split(';')
            dataDB=[aux[0],aux[2],aux[4],aux[5],aux[6],file_name,ciclo,capacidad]
            try:
                insert_cycle_data(conn,estados,dataDB)
            except:
                print('problemas con ingresar datos en la base de datos')
    return 

def monitor_serial_port(ciclo:str|int, port='COM3', baudrate=9600,timeout_seconds=60, log_to_file=False, conn=None):
    """Only Reads the data from Serial COM port and saves it into a local postgreDB and CSV files

    Args:
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
            if isinstance(ciclo,int):
                manipulable_cycle=ciclo #variable for operating during runtime
            else:
                manipulable_cycle=int(ciclo) #variable for operating during runtime
            print(log_to_file)
            if log_to_file:#proceed to create the files to save raw data.
                # save_file(mode=1, ciclo=manipulable_cycle)
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
                        output = f"{timestamp};{diff};{manipulable_cycle};{data}"
                        print(output)
                        cycle_history.append(output.split('$')[1].split(';')[1])
                        if cycle_history[-5:]==['4','4','1','1','1']:
                            manipulable_cycle+=1
                            base_time=datetime.now()
                        elif cycle_history[-5:]==['6','6','6','6','6']:
                            break
                        try: #trying to save the data
                            if log_to_file:
                                # save_file(mode=2,raw_data=output)
                                print("saving data into the book")
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
            if len(temp_memory)>0:
                print("There was data not saved because of Excel opened")
                # save_file(mode=2)
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
    
    submit_button = ttk.Button(root, text=f"Submit + {confirmation}", command=on_submit)
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
    # threading.Thread(target=open_second_window, daemon=True).start()
    # threading.Thread(target=run_main_script, daemon=True).start()
    run_main_script()

    # Keep the main thread alive
    # while not main_script_done:
    #     time.sleep(1)
    print("done")
