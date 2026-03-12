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

#time libraries
import time
from datetime import datetime
import glob
from collections import Counter

#library for database
import sql

#for parallel processing
import threading
import os


class App:
    def __init__(self,root):
        self.root = root
        self.tabs=["+"]
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

    def __save_file(self, mode:int, naming:list, raw_data:str|list='', last_duration:float=0, stages_history:list=[], conn=None):
    
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
            modified_data,estados=self.__extract_columns(raw_data,data_history=stages_history)

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
                        self.__insert_cycle_data(conn,estados,dataDB)
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
                modified_data,estados=self.__extract_columns(a,data_history=stages_history[-5:])
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
                        self.__insert_cycle_datainsert_cycle_data(conn,estados,dataDB)
                    except:
                        print('problemas con ingresar datos en la base de datos')
                state_file.write(modified_data+'\n')
                state_file.flush()
                state_file.close()
            return

    def final_checking(self, naming: list):

            bateria = naming[0]
            capacidad = naming[1]
            ciclo = naming[2]
            folder = naming[3]

            raw_file = f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv"

            if not os.path.exists(raw_file):
                print("Raw file missing")
                return

            with open(raw_file, "r") as f:
                raw_lines = f.readlines()

            raw_rows = raw_lines[1:]
            raw_count = len(raw_rows)

            pattern = f"{folder}\\{bateria}*_{capacidad}_{ciclo}.csv"
            processed_files = glob.glob(pattern)

            processed_count = 0
            processed_set = set()

            for file in processed_files:

                with open(file, "r") as f:
                    lines = f.readlines()[1:]

                    processed_count += len(lines)
                    processed_set.update(lines)

            print("Raw rows:", raw_count)
            print("Processed rows:", processed_count)

            if processed_count >= raw_count:
                print("Files verified OK")
                return

            print("Repairing missing rows...")

            for raw in raw_rows:

                raw = raw.strip()

                modified_data, estado = self.__extract_columns(raw)

                line = modified_data + '\n'

                if line not in processed_set:

                    file_name = f"{folder}\\{bateria}{estado}_{capacidad}_{ciclo}.csv"

                    if not os.path.exists(file_name):

                        with open(file_name, "w") as f:
                            f.write(
                                'date;system_time;cycle_time;cycle_number;battery_state;voltage[V];current[mA];capacity[mAh]\n'
                            )

                    with open(file_name, "a") as f:
                        f.write(line)

            print("Final check completed")

    def monitor_serial_port(self, naming:list, tab, queue, port='COM3', baudrate=9600,timeout_seconds=60, log_to_file=False, conn=None):
        """Reads and saves the data from Serial COM port and saves it into a local postgreDB and CSV files

        Args:            
            naming (list): [0] Batery, [1] Capacity, [2] Cycle number, [3] folder
            port (str, optional): COM port from which to read the data. Defaults to 'COM3'.
            baudrate (int, optional): baudrate at which to read data from com port. Defaults to 9600.
            log_to_file (bool, optional): Determines if data is to be saved in a file. Defaults to False.
            timeout_seconds (int, optional): _description_. Defaults to 60.
            conn (_type_, optional): Connection to postgreDB credentials. Defaults to None.
        """
        ciclo=int(naming[2])
        
        try:
            with serial.Serial(port, baudrate, timeout=1) as ser:
                # print(f"monitor_serial_port function:\nMonitoring {port} at {baudrate} baud. Timeout after {timeout_seconds} seconds of inactivity.")
                queue.put(f"monitor_serial_port function:\nMonitoring {port} at {baudrate} baud. Timeout after {timeout_seconds} seconds of inactivity.")
                
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
                    self.__save_file(mode=1,naming=naming)
                    print("Creating raw data file")
                    temp_memory=[]
                #data recording
                while True:
                # for i in range(500): #for testing purposes
                    timestamp = time.strftime("%Y-%m-%d;%H:%M:%S")
                    # print(f'{timestamp},{ser.in_waiting}')
                    queue.put(f'{timestamp},{ser.in_waiting}')
                    if ser.in_waiting >0:
                        data = ser.readline().decode('utf-8', errors='ignore').strip()
                        if data:
                            diff=abs(base_time-datetime.now())
                            cycle_history.append(data.split(';')[1])
                            output = f"{timestamp};{diff};{manipulable_cycle};{data}"
                            # print(output)
                            queue.put(output)
                            if cycle_history[-5:]==['4','4','1','1','1']:
                                manipulable_cycle+=1
                                base_time=datetime.now()
                            elif cycle_history[-5:]==['6','6','6','6','6']: #if received this information, it's finished 
                                break

                            try: #trying to save the data
                                stage=cycle_history[-5:]
                                if log_to_file:
                                    self.__save_file(mode=2,raw_data=output, 
                                            last_duration=duration, 
                                            stages_history=stage, 
                                            naming=naming, conn=conn)
                                duration=0
                                [duration:= duration+float(x) for x in output.split('$')[0].split(';')[-3].split(':')]
                            except PermissionError: #the CSV file is opened by another program
                                temp_memory.append(output)
                            last_activity_time = time.time()
                    else:
                        print("No data received ", port)
                        queue.put("No data received "+ port)
                    # Check for timeout
                    if time.time() - last_activity_time > timeout_seconds:
                        # print(f"\nNo data received for {timeout_seconds} seconds. Exiting.")
                        break
                    time.sleep(0.1)  # avoid busy loop

        except serial.SerialException as e:
            print(f"Serial error: {e}")
        except KeyboardInterrupt:
            print("\nMonitoring stopped by user.")
        finally:
            print("Done monitoring Serial COM port")
            try:
                ser.close()
            except:
                pass

            print("Last cycle:", manipulable_cycle)

            if log_to_file:
                try:
                    if len(temp_memory) > 0:
                        print("Saving temp memory")
                        self.__save_file(
                            mode=3,
                            raw_data=temp_memory,
                            naming=naming,
                            conn=conn
                        )
                except:
                    print("No temp memory")

                # -------- FINAL CHECK HERE --------
                try:
                    self.final_checking(naming)
                except Exception as e:
                    print("Final check failed:", e)
                # ----------------------------------

            self.info[tab]["stop"].set()
            try:
                self.info[tab]["thread"].join()
            except:
                print("problem with threading")
                pass

            for _ in range(5):
                print("*"*100)
                queue.put("******************")
            print("Finished program", time.strftime("%Y-%m-%d;%H:%M:%S"))
            queue.put("Finished program: "+ time.strftime("%Y-%m-%d;%H:%M:%S"))
            for _ in range(5):
                print("*"*100)
                queue.put("******************")
        return

    ##********************************************
    ##GUI
    #*********************************************
    def __update_tab_output(self, text_widget, data_queue):
        while not data_queue.empty():
            text_widget.insert("end", data_queue.get() + "\n")
            text_widget.see("end")
        text_widget.after(100, self.__update_tab_output, text_widget, data_queue)

    def on_tab_change(self, event):
        selected = self.notebook.select()
        # Print the name of the selected tab
        tab_name = self.notebook.tab(selected, "text")
        if tab_name=="+": #adding new tab
            name="Bat "+str(len(self.tabs))
            self.tabs.append(name)
            self.tabs[-1]= ttk.Frame(self.notebook)
            self.notebook.add(self.tabs[-1], text=name)
            self.notebook.select(self.tabs[-1])
            # creating user inputs interfaces
            self.user_inputs(self.tabs[-1], name,self.__list_ports())
            
            print("Updating user interface")
            #showing the capture information and start reading from monitor serial
            self.__second_interface(self.tabs[-1],name)           
            
            # #starting running monitor serial
            # self.__run_main_script(name)
        else:
            print(f"User selected tab: {tab_name}")

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
                if self.info[tab_name][y]=='':
                    self.info[tab_name][y]=os.getcwd()
                
                print(self.info[tab_name])
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

    def __second_interface(self, root, tab_name):
        '''
        Updates the interface to label show the information on the battery and a terminal like to show the information read from the COM port
        '''
        self.notebook.tab(root, text=self.info[tab_name]["Bateria"])
        
        top_frame = ttk.Frame(root)
        top_frame.pack(side=tk.TOP, fill=tk.X)
        #labels with information about the battery
        for key, value in self.info[tab_name].items():
            ttk.Label(top_frame, text=f"{key}: {value}").pack(anchor='w')

        #terminal space showing the information 
        terminal_frame = ttk.Frame(root)
        terminal_frame.pack(side=tk.TOP, fill=tk.BOTH, expand=True)

        #text area
        text = tk.Text(terminal_frame, height=15)
        text.pack(expand=True, fill="both")
    
        print('*'*100)
        print("Reading data for: ",self.info[tab_name]["Bateria"])
        
        # trying to read database credential
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
        #setting naming list [battery, capacity, cycle, folder]
        naming=[y for x,y in enumerate(self.info[tab_name].values()) if x<5 and x>0]
        
        #reading COM port data
        q=queue.Queue()
        stop_event = threading.Event()

        t=threading.Thread(
            target=self.monitor_serial_port,
            args=(naming, tab_name, q, 
                  self.info[tab_name]['COM port'], 
                  self.info[tab_name]['Baud rate'],60,True),
            daemon=True
        )
        
        t.start()
        text.insert("end", "Test data\n")
        self.__update_tab_output(text, q)

        # self.info[tab_name]["data"]=q
        self.info[tab_name]["thread"]=t
        self.info[tab_name]["stop"]=stop_event

        return   
    
if __name__ == '__main__':
    # Run the app
    root = tk.Tk()

    app = App(root)
    root.mainloop()