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

# Global variables
user_inputs = {}
user_inputs['COM port']='COM4'
user_inputs['Baud rate']=9600
user_inputs['Bateria']=''
user_inputs['Capacidad nominal']=''
user_inputs['Ciclo']=''
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
    return delimiter.join(result),estado #return the data as string

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


def save_file(estado:str,bateria:str,capacidad:str,ciclo:str,folder:str,data:str,base_time:datetime,stages_history:list,data_history:dict,conn=None):
    """Saves the information in a dedicated charging, rest, discharging battery file


    Args:
        estado (str): Charging, Resting, Discharging or finished
        bateria (str): Battery number
        capacidad (str): Battery nominal capacity
        ciclo (str): Battery current cycle
        folder (str): File path to save the data
        data (str): Data to save into files
        base_time (datetime): The time when the current state started
        stages_history (list): Recollection of the past data stages
        data_history (dict): History of the saved files
        conn (_type_, optional): Connection to postgreDB. Defaults to None.

    Returns:
        ciclo (str): returns the current battery cicle (charging-rest-discharging-rest) is considered 1 cycle
        base_timme (datetime): return the "starting time" of the battery stage 
        estados_pasados (list): return a list of the past 4 stages of the data.
    """    
    stages_history.append(estado.lower())
    #determine the correct battery state (charging, resting, discharging) to save data to
    if len(stages_history)>4:
        if all(x==estado.lower() for x in stages_history):
            file_name=f"{folder}\\{bateria}{estado.lower()}_{capacidad}_{ciclo}.csv"
        else:
            most_common_elem, count = Counter(stages_history).most_common(1)[0]
            if most_common_elem=="charging" and count==3 and estado.lower()=='charging':
                ciclo+=1
            file_name=f"{folder}\\{bateria}{most_common_elem}_{capacidad}_{ciclo}.csv"
        if not(file_name in data_history):
            data_history[file_name]=time.asctime(time.localtime())#register the time when the new file began recording
            base_time=datetime.now() #get the time when the data recording starts for the new stage
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
            state_file.write(data+'\n')
            state_file.flush()
        
        #writing to DB
        #formato [date, cycle_time,voltage,current,capacity,file,cycle_number,nominal_capacity]
        if not(conn is None):
            aux=data.split(';')
            dataDB=[aux[0],aux[2],aux[4],aux[5],aux[6],file_name,ciclo,capacidad]
            try:
                insert_cycle_data(conn,estado,dataDB)
            except:
                print('problemas con ingresar datos en la base de datos')
    return ciclo,base_time,stages_history

def monitor_serial_port(bateria:str,capacidad:str,ciclo:str,folder:str,port='COM3', baudrate=9600, log_to_file=False, timeout_seconds=60,conn=None):
    """Reads and saves the data from Serial COM port and saves it into a local postgreDB and CSV files

    Args:
        bateria (str): Battery number
        capacidad (str): Battery nominal capacity
        ciclo (str): Battery starting cycle
        folder (str): File path to save the data
        port (str, optional): COM port from which to read the data. Defaults to 'COM3'.
        baudrate (int, optional): baudrate at which to read data from com port. Defaults to 9600.
        log_to_file (bool, optional): Determines if data is to be saved in a file. Defaults to False.
        timeout_seconds (int, optional): _description_. Defaults to 60.
        conn (_type_, optional): Connection to postgreDB credentials. Defaults to None.
    """    
    #auxiliary runtime variables
    log_file=False
    estados_pasados=[]
    dict_data={}
    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            print(f"monitor_serial_port function:\nMonitoring {port} at {baudrate} baud. Timeout after {timeout_seconds} seconds of inactivity.")
            base_time=datetime.now() #captures the time when data begins
            
            if log_to_file:
                log_file = open(f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv", "w")
                log_file.write('date;system_time;cycle_time;data starting; cycle; empty; provided voltage; voltage (mV); current (cA); battery1; battery2; battery3; battery4; battery5; battery6; unknown0; unknown1; capacity (mAh); unknown2'+'\n')#setting column titles
                log_file.flush()
            else:
                log_file = None

            last_activity_time = time.time()

            #data recording
            while True:
            # for i in range(10): #for testing purposes
                timestamp = time.strftime("%Y-%m-%d;%H:%M:%S")
                print(f'{timestamp}, {ser.in_waiting}')
                if ser.in_waiting >0:
                    data = ser.readline().decode('utf-8', errors='ignore').strip()
                    if data:
                        diff=str(abs(base_time-datetime.now()))
                        output = f"{timestamp};{diff};{data}"
                        print(output)
                        
                        modified_data,estado=extract_columns(output)
                        if estados_pasados==['finished','finished','finished','finished']:
                            print("finished cicles \nclosing program")
                            break
                        #insert var to keep data while excel file is open
                        if log_to_file:
                            #original data
                            if log_file:
                                log_file.write(output + '\n')
                                log_file.flush()
                                ciclo,base_time,estados_pasados=save_file(estado=estado,
                                                                          base_time=base_time,
                                                                          bateria=bateria,
                                                                          capacidad=capacidad,
                                                                          ciclo=ciclo,
                                                                          conn=conn,
                                                                          data=modified_data,
                                                                          data_history=dict_data,
                                                                          folder=folder,
                                                                          stages_history=estados_pasados
                                                                          )
                        
                        last_activity_time = time.time()
                else:
                    print(timestamp, "No data received")
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
            for y in aux[2:]:
                user_inputs[y]=user_inputs[y].get()
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

    #creates input boxes    
    for i,j in enumerate(aux[2:]):
        ttk.Label(root, text=f"{j}: ").grid(row=i+1, column=0, pady=5)
        entry = tk.Entry(root)
        entry.grid(row=i+1, column=1, pady=5)
        user_inputs[j]=entry
    
    submit_button = ttk.Button(root, text=f"Submit + {confirmation}", command=on_submit)
    submit_button.grid(row=len(user_inputs.keys())+1, column=0, columnspan=2)

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

    #reading COM port data
    monitor_serial_port(
        bateria=user_inputs['Bateria'],
        baudrate=9600,
        capacidad=user_inputs['Capacidad nominal'],
        ciclo=user_inputs['Ciclo'],
        folder=user_inputs['Ruta de folder'],
        log_to_file=True,
        port=user_inputs['COM port'],
        timeout_seconds=10,
        conn=conn
    )
    print("Main script finished.")
    main_script_done = True    
    if not second_window:
        threading.Thread(target=open_second_window, daemon=True).start()

# Launch
if __name__ == '__main__':
    open_input_window(list_com_ports())
    threading.Thread(target=open_second_window, daemon=True).start()
    threading.Thread(target=run_main_script, daemon=True).start()

    # Keep the main thread alive
    while not main_script_done:
        time.sleep(1)
    print("done")
