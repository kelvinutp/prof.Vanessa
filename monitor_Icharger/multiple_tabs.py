import tkinter as tk
from tkinter import ttk
import threading
import queue
import serial
import time
import os
from datetime import datetime
from collections import Counter
import serial.tools.list_ports
import traceback

# ======================================================
# ---------------- DATA PROCESSING ---------------------
# ======================================================

def extract_columns(data, delimiter=';', data_history:list=[]):
    aux = 0
    aux2 = False
    columns = data.split(delimiter)
    result = []
    estado = None

    for i in columns:
        if '$' in i:
            aux2 = True

        if aux2:
            if aux in [1, 4, 5, 14]:
                if aux == 1:
                    if data_history:
                        most_common_elem, _ = Counter(data_history).most_common(1)[0]
                        if most_common_elem != i.strip():
                            i = most_common_elem

                    if i.strip() == '1':
                        estado = 'charging'
                    elif i.strip() == '2':
                        estado = 'discharging'
                    elif i.strip() == '4':
                        estado = 'rest'
                    elif i.strip() == '6':
                        estado = 'finished'

                    result.append(estado)

                elif aux == 4:
                    result.append(str(int(i)/1000))
                elif aux == 5:
                    result.append(str(int(i)/100))
                else:
                    result.append(i)
            aux += 1
        else:
            result.append(i)

    return delimiter.join(result), estado

# ======================================================
# ---------------- FILE WRITER ------------------------
# ======================================================

class FileWriter(threading.Thread):
    def __init__(self, file_q):
        super().__init__(daemon=True)
        self.file_q = file_q
        self.stop_event = threading.Event()

    def run(self):
        while not self.stop_event.is_set() or not self.file_q.empty():
            try:
                task = self.file_q.get(timeout=0.1)
            except queue.Empty:
                continue

            try:
                self._process_task(task)
            except Exception as e:
                print(f"{datetime.now()}-❌ FileWriter task failed: {e}")
                traceback.print_exc()

    def _process_task(self, task):
        mode = task.get("mode")
        folder = task.get("folder")
        bateria = task.get("bateria")
        capacidad = task.get("capacidad")
        ciclo = task.get("ciclo")
        raw_data = task.get("raw_data","")
        stages_history = task.get("stages_history",[])
        last_duration = task.get("last_duration",0)

        os.makedirs(folder, exist_ok=True)
        raw_file = f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv"        

        if mode == 1:
            with open(raw_file,"w") as f:
                f.write(
                    'date;system_time;cycle_time;cycle_number;data starting;cycle;empty;'
                    'provided voltage;voltage (mV);current (cA);battery1;battery2;'
                    'battery3;battery4;battery5;battery6;unknown0;unknown1;capacity (mAh);unknown2\n'
                )
            return

        if mode == 2:
            with open(raw_file,"a") as f:
                f.write(raw_data+"\n")

            try:
                ciclo_val = raw_data.split('$')[0].split(';')[-2]
                cycle_time = sum(float(x) for x in raw_data.split('$')[0].split(';')[-3].split(':'))
            except Exception:
                ciclo_val = ciclo
                cycle_time = 0

            modified_data, estado = extract_columns(raw_data, data_history=stages_history)
            state_file = f"{folder}/{bateria}{estado}_{capacidad}_{ciclo_val}.csv"

            if last_duration == 0 or last_duration > cycle_time:
                with open(state_file,"w") as f:
                    f.write(
                        'date;system_time;cycle_time;cycle_number;'
                        'battery_state;voltage[V];current[mA];capacity[mAh]\n'
                    )

            with open(state_file,"a") as f:
                f.write(modified_data+"\n")

# ======================================================
# ---------------- SERIAL HELPERS ----------------------
# ======================================================

def list_com_ports():
    ports = serial.tools.list_ports.comports()
    return [port.device for port in ports]

COMMON_BAUDS = [9600, 19200, 38400, 57600, 115200, 230400]

def detect_baud(port):
    for baud in COMMON_BAUDS:
        try:
            with serial.Serial(port, baud, timeout=0.5) as ser:
                time.sleep(0.2)
                for _ in range(5):
                    line = ser.readline().decode(errors="ignore")
                    if '$' in line and ';' in line:
                        return baud
        except serial.SerialException:
            pass
    return None

# ======================================================
# ---------------- SERIAL MONITOR ----------------------
# ======================================================

def monitor_serial_thread(config, log_q, file_q, stop_event, TIMEOUT_SECONDS=10):
    port = config["port"]
    naming = config["naming"]
    battery_name = naming[1]

    #self selection
    baud = detect_baud(port)
    # if baud is None:
    #     log_q.put(f"❌ Baud detection failed ({battery_name})")
    #     return

    #manually selection   
    baud=config["baud"]
    log_q.put(f"Baud detected: {baud}")

    last_state = None
    cycle_history = []
    duration = 0
    temp_cycle=int(naming[3])

    # Initialize file original data
    file_q.put({
        "mode": 1,
        "folder": naming[0],
        "bateria": naming[1],
        "capacidad": naming[2],
        "ciclo": naming[3]
    })
    print(f"{datetime.now()}- starting monitor serial function - {battery_name}")

    try:
        with serial.Serial(port, baud, timeout=1) as ser:
            base_time = datetime.now()
            last_rx_time = time.monotonic()

            while not stop_event.is_set():
                if ser.in_waiting > 0:
                    data = ser.readline().decode(errors="ignore").strip()
                    if data:
                        last_rx_time = time.monotonic()
                        timestamp = time.strftime("%Y-%m-%d;%H:%M:%S")
                        diff = abs(base_time - datetime.now())
                        output = f"{timestamp};{diff};{temp_cycle};{data}"

                        # send to UI
                        log_q.put(output)

                        # send to file writer
                        file_q.put({
                            "mode": 2,
                            "folder": naming[0],
                            "bateria": naming[1],
                            "capacidad": naming[2],
                            "ciclo": naming[3],
                            "raw_data": output,
                            "stages_history": cycle_history[-5:],
                            "last_duration": duration
                        })

                        try:
                            stage_code = data.split(';')[1]
                            cycle_history.append(stage_code)
                            _, state = extract_columns(output, data_history=cycle_history[-5:])
                        except Exception:
                            state = None

                        if state and state != last_state:
                            last_state = state
                            if state=="charging":
                                temp_cycle+=1
                            
                            base_time = datetime.now()
                            print(f"{datetime.now()}- New cycle state:{state} - {battery_name}")

                        try:
                            duration = sum(float(x) for x in output.split('$')[0].split(';')[-3].split(':'))
                        except Exception:
                            duration = 0

                        if state == "finished":
                            log_q.put(f"🏁 Cycle finished ({battery_name})")
                            break

                if time.monotonic() - last_rx_time > TIMEOUT_SECONDS:
                    log_q.put(f"⏱ No data for {TIMEOUT_SECONDS}s ({battery_name}). Closing monitor.")
                    break

                time.sleep(0.1)

    except Exception as e:
        log_q.put(f"❌ Serial error ({battery_name}): {e}")
        traceback.print_exc()
    
    print(f"{datetime.now()}- exiting monitor serial function - {battery_name}")

# ======================================================
# -------------------- UI TAB --------------------------
# ======================================================

class BatteryTab:
    def __init__(self, notebook, tab_name, com_ports, file_q):
        self.notebook = notebook
        self.tab_name = tab_name
        self.frame = ttk.Frame(notebook)
        notebook.add(self.frame, text=tab_name)

        self.com_ports = com_ports
        self.log_q = queue.Queue()
        self.stop_event = threading.Event()
        self.info = {}
        self.file_q = file_q

        self._user_inputs(self.frame)

    def _user_inputs(self, root):
        btn_text = tk.StringVar(value="Confirmar datos")
        fields = ["Bateria","Capacidad nominal","Ciclo","Ruta de folder"]

        #manual selection
        # Available baud rates
        baud_options = [9600, 19200, 38400, 57600, 115200, 230400]

        def on_submit():
            if btn_text.get() == "Confirmar datos":
                btn_text.set("Iniciar grabacion de datos")
                return

            self.info["COM port"] = dropdown_var.get()
            self.info["Baud rate"] = int(baud_var.get())  # Save selected baud rate

            for f in fields:
                val = entries[f].get()
                if f=="Ruta de folder" and not val:
                    val = os.getcwd()
                self.info[f] = val

            for w in root.winfo_children():
                w.destroy()

            self._second_interface(root)

        # COM port selection
        ttk.Label(root, text="COM port:").grid(row=0,column=0)
        dropdown_var = tk.StringVar()
        ttk.Combobox(root, values=self.com_ports, textvariable=dropdown_var).grid(row=0,column=1)

        # Baud rate manual selection
        ttk.Label(root, text="Baud rate:").grid(row=1, column=0)
        baud_var = tk.StringVar(value=str(115200))  # default value
        ttk.Combobox(root, values=baud_options, textvariable=baud_var).grid(row=1,column=1)

        # Other fields
        entries = {}
        for i,name in enumerate(fields):
            ttk.Label(root,text=name).grid(row=i+2,column=0,sticky="w")  # shift rows by +2
            e = ttk.Entry(root,width=40)
            e.grid(row=i+2,column=1)
            entries[name]=e

        ttk.Button(root,textvariable=btn_text,command=on_submit).grid(row=len(fields)+2,column=0,columnspan=2,pady=10)


    def _second_interface(self, root):
        self.notebook.tab(root, text=self.info["Bateria"])

        header = ttk.Frame(root)
        header.pack(fill=tk.X,padx=5,pady=5)

        self.baud_var = tk.StringVar(value="Detecting...")
        self.com_var = tk.StringVar(value=self.info["COM port"])

        info_items = [
            ("Batería", self.info["Bateria"]),
            ("Capacidad nominal", self.info["Capacidad nominal"]),
            ("Ciclo", self.info["Ciclo"]),
            ("Ruta de folder", self.info["Ruta de folder"]),
            ("COM port", self.com_var),
            ("Baud rate", self.baud_var)#manual selection
        ]

        for i,(label,value) in enumerate(info_items):
            ttk.Label(header,text=f"{label}:",font=("Segoe UI",9,"bold")).grid(row=i,column=0,sticky="w",padx=(0,5))
            if isinstance(value,tk.StringVar):
                ttk.Label(header,textvariable=value).grid(row=i,column=1,sticky="w")
            else:
                ttk.Label(header,text=value,wraplength=600).grid(row=i,column=1,sticky="w")

        ttk.Separator(root,orient="horizontal").pack(fill=tk.X,padx=5,pady=5)
        terminal = tk.Text(root,height=15)
        terminal.pack(fill=tk.BOTH,expand=True,padx=5,pady=5)

        naming = [
            self.info["Ruta de folder"],
            self.info["Bateria"],
            self.info["Capacidad nominal"],
            self.info["Ciclo"]
        ]

        threading.Thread(
            target=monitor_serial_thread,
            # args=({"port": self.info["COM port"],"naming": naming}, self.log_q, self.file_q, self.stop_event),
            args=({"port": self.info["COM port"],"baud":self.baud_var,"naming": naming}, self.log_q, self.file_q, self.stop_event), #manual selection
            daemon=True
        ).start()

        self._update_terminal(terminal)

    def _update_terminal(self, terminal):
        while not self.log_q.empty():
            msg = self.log_q.get()
            terminal.insert(tk.END,msg+"\n")
            terminal.see(tk.END)
            # Update baud if detected
            if "Baud detected:" in msg:
                self.baud_var.set(msg.split(":")[-1].strip())
        terminal.after(100,self._update_terminal,terminal)

# ======================================================
# -------------------- MAIN APP ------------------------
# ======================================================

class App:
    def __init__(self, root):
        root.title("Icharger Multi-Battery Logger")
        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill="both",expand=True)

        self.com_ports = list_com_ports()
        self.battery_count = 0

        # Single FileWriter thread
        self.file_q = queue.Queue()
        self.file_writer = FileWriter(self.file_q)
        self.file_writer.start()

        self.add_battery_tab()
        self.plus_tab = ttk.Frame(self.notebook)
        self.notebook.add(self.plus_tab,text="+")
        self.notebook.bind("<<NotebookTabChanged>>",self.on_tab_changed)

    def add_battery_tab(self):
        self.battery_count += 1
        BatteryTab(self.notebook,f"Battery {self.battery_count}",self.com_ports,self.file_q)

    def on_tab_changed(self,event):
        tab_id = event.widget.select()
        if event.widget.tab(tab_id,"text") == "+":
            self.notebook.forget(self.plus_tab)
            self.add_battery_tab()
            self.plus_tab = ttk.Frame(self.notebook)
            self.notebook.add(self.plus_tab,text="+")
            self.notebook.select(self.notebook.tabs()[-2])

if __name__=="__main__":
    root = tk.Tk()
    App(root)
    root.mainloop()
