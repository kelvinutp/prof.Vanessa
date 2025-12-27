#GUI libraries
import tkinter as tk
from tkinter import ttk

#connection to COM ports
import serial.tools.list_ports #to list com ports
import serial #to establish communication with the selected com port

#db library connection 
import psycopg2

#library for redirecting print output to terminal 
import queue
import sys

#time libraries
import time
from datetime import datetime

from collections import Counter
import sql

#for parallel processing
import threading
from threading import Event


#Redirect print to queu
# console_queue = queue.Queue()
# class QueuePrinter:
#     def write(self, msg):
#         if msg.strip() != '':
#             console_queue.put(msg+'\n')

#     def flush(self):
#         pass

# sys.stdout = QueuePrinter()

class App:
    def __init__(self,root):
        self.root = root
        self.tabs=["+","Bat 1"]
        self.info={} #key: tab name #value:{self.info[tab_name]:[com port, baud rate, "Bateria", "Capacidad nominal", "Ciclo", "Ruta de folder", "Credenciales de base de dato"}
        self.root.title("Monitor battery")
        self.root.geometry("700x400")
        
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill="both", expand=True)

        # Defatul tabs
        self.tabs[0]=ttk.Frame(self.notebook)
        
        self.notebook.add(self.tabs[0], text="+")        
        self.notebook.bind("<<NotebookTabChanged>>", self.on_tab_change)

    def __list_ports(self):
        """
        Lists all available COM ports on the system.
        Returns a list of COM port names (e.g., COM1, COM2, COM3).
        """
        print("Listing all available COM ports:")
        taken=[]
        ports = serial.tools.list_ports.comports()  # Get a list of serial ports
        if ports:
            for index, port in enumerate(ports):
                print(f"{index}.Port: {port.device}, Description: {port.description}")
                for b,a in self.info.items():
                    if port.device in a.values():
                        print("port is being used by battery: ",b)
                        taken.append(port)

        else:
            print("No COM ports found.")
        return [port.device+"(in use)" if port in taken else port.device for port in ports]
    
    def __extract_columns(self, data,delimiter=';'):
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

    def __insert_cycle_data(self, conn, cycle: str, data: list):
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

    def __save_file(self, estado:str,bateria:str,capacidad:str,ciclo:str,folder:str,data:str,base_time:datetime,stages_history:list,data_history:dict,conn=None):
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
                    self.__insert_cycle_data(conn,estado,dataDB)
                except:
                    print('problemas con ingresar datos en la base de datos')
        return ciclo,base_time,stages_history

    def monitor_serial_port(self, bateria:str,capacidad:str,ciclo:str,folder:str,port='COM3', baudrate=9600, log_to_file=False, timeout_seconds=60,conn=None):
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
        temp_memory=[] #saves the raw data that was not recorded in CSV file
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
            serial.close()
            # stop_event.set()
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
    def on_tab_change(self, event):
        selected = self.notebook.select()

        # Print the name of the selected tab
        tab_name = self.notebook.tab(selected, "text")
        if tab_name=="+": #adding new tab
            name="Bat "+str(len(self.tabs))
            self.tabs.append(name)
            self.tabs[-1]= ttk.Frame(self.notebook)
            self.notebook.add(self.tabs[-1], text=name)
            # creating user inputs interfaces
            self.user_inputs(self.tabs[-1], name,self.__list_ports())
            
            #showing the capture information and start reading from monitor serial
            self.__running_program(self.tabs[-1],name)
        # else:
        #     print(f"User selected tab: {tab_name}")

    def user_inputs(self, root, tab_name, com_ports:list):
        """creating user inputs interfaces
        """
        print("*"*100)
        print("Waiting for user inputs")
        self.info[tab_name]={
            "Baud rate":9600            
        }
        global btn_text
        
        btn_text = tk.StringVar(value="Confirmar datos")
        aux=["Bateria", "Capacidad nominal", "Ciclo", "Ruta de folder", "Credenciales de base de dato"]

        def on_submit():            
            if btn_text.get()=="Confirmar datos":
                btn_text.set("Iniciar grabacion de datos")
                return
            elif btn_text.get()=="Iniciar grabacion de datos":
                self.info[tab_name]['COM port']=dropdown_var.get()
                for y in aux:
                    self.info[tab_name][y]=self.info[tab_name][y].get()                
                print(self.info)
                #reset windows for new elements
                for a in root.winfo_children():
                    a.destroy()
                root.quit() 
                return 
        #dropbox for selecting comm port
        ttk.Label(root, text="COM port:").grid(row=0, column=0, pady=5)
        dropdown_var = tk.StringVar()
        dropdown = ttk.Combobox(root, textvariable=dropdown_var)
        dropdown['values'] = com_ports
        dropdown.grid(row=0, column=1, pady=5)

        #creates input boxes
        for i,j in enumerate(aux):
            ttk.Label(root, text=f"{j}: ").grid(row=i+1, column=0, pady=5)
            entry = tk.Entry(root)
            entry.grid(row=i+1, column=1, pady=5)
            self.info[tab_name][j]=entry
        
        submit_button = ttk.Button(root, textvariable=btn_text, command=on_submit)
        submit_button.grid(row=len(aux)+1, column=0, columnspan=2)
        root.mainloop()

    def __running_program(self, root, tab_name):
        print("*"*100)
        print("Running program")
        print("Reading data for: ",self.info[tab_name]["Bateria"])
        self.notebook.tab(root, text=self.info[tab_name]["Bateria"])
        
        top_frame = ttk.Frame(root)
        top_frame.pack(side=tk.TOP, fill=tk.X)
        #labels with information about the battery
        for key, value in self.info[tab_name].items():
            ttk.Label(top_frame, text=f"{key}: {value}").pack(anchor='w')

        #terminal space showing the information 
        terminal_frame = ttk.Frame(root)
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
        
        #trying to read database credential
        try:
            a=self.info[tab_name]['dB credential file']
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

        # #reading COM port data
        self.threads = []
        stop_event = Event()
        t=threading.Thread(
            target=monitor_serial_port,
            args=(self.info[tab_name]["Ciclo"]
                naming=[y for x,y in enumerate(self.info[tab_name].values()) if x<4]
                port=self.info[tab_name]['COM port'],
                baudrate=9600,
                timeout_seconds=60,
                log_to_file=True,
                conn=conn
                ),
            daemon=True
        )
        threads.append(t)
        t.start()
        # monitor_serial_port(
        #     bateria=self.info[tab_name]['Bateria'],
        #     baudrate=9600,
        #     capacidad=self.info[tab_name]['Capacidad nominal'],
        #     ciclo=self.info[tab_name]['Ciclo'],
        #     folder=self.info[tab_name]['Ruta de folder'],
        #     log_to_file=True,
        #     port=self.info[tab_name]['COM port'],
        #     timeout_seconds=10,
        #     conn=conn
        # )
        print("Main script finished.")
        time.sleep(120)

# Run the app
root = tk.Tk()

app = App(root)
root.mainloop()