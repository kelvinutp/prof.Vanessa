import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import threading
import queue
import serial
import time
import os
from datetime import datetime
from collections import Counter

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
                    result.append(str(int(i) / 1000))
                elif aux == 5:
                    result.append(str(int(i) / 100))
                else:
                    result.append(i)
            aux += 1
        else:
            result.append(i)

    return delimiter.join(result), estado


def save_file(mode:int, naming:list, raw_data:str='',
              last_duration:float=0, stages_history:list=[]):

    folder, bateria, capacidad, ciclo = naming
    raw_file = f"{folder}/data_original_{bateria}_{capacidad}_{ciclo}.csv"

    if mode == 1:
        with open(raw_file, "w") as f:
            f.write(
                'date;system_time;cycle_time;cycle_number;data starting;cycle;empty;'
                'provided voltage;voltage (mV);current (cA);battery1;battery2;'
                'battery3;battery4;battery5;battery6;unknown0;unknown1;capacity (mAh);unknown2\n'
            )
        return

    if mode == 2:
        with open(raw_file, "a") as f:
            f.write(raw_data + "\n")

        ciclo = raw_data.split('$')[0].split(';')[-2]
        cycle_time = sum(float(x) for x in raw_data.split('$')[0].split(';')[-3].split(':'))

        modified_data, estado = extract_columns(raw_data, data_history=stages_history)

        state_file = f"{folder}/{bateria}{estado}_{capacidad}_{ciclo}.csv"

        if last_duration == 0 or last_duration > cycle_time:
            with open(state_file, "w") as f:
                f.write(
                    'date;system_time;cycle_time;cycle_number;'
                    'battery_state;voltage[V];current[mA];capacity[mAh]\n'
                )

        with open(state_file, "a") as f:
            f.write(modified_data + "\n")


# ======================================================
# ---------------- SERIAL HELPERS ----------------------
# ======================================================

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
# ---------------- THREAD FUNCTION ---------------------
# ======================================================

def monitor_serial_thread(config, log_q, stop_event):
    port = config["port"]
    naming = config["naming"]
    battery_name = naming[1]

    baud = detect_baud(port)
    if baud is None:
        print(f"[{battery_name}] ❌ Baud detection failed")
        log_q.put("❌ Baud detection failed")
        return

    print(f"[{battery_name}] ▶ Started reading (baud={baud})")
    log_q.put(f"Baud detected: {baud}")

    last_state = None
    cycle_history = []
    duration = 0

    save_file(mode=1, naming=naming)

    try:
        with serial.Serial(port, baud, timeout=1) as ser:
            base_time = datetime.now()

            while not stop_event.is_set():
                if ser.in_waiting > 0:
                    data = ser.readline().decode(errors="ignore").strip()
                    if not data:
                        continue

                    timestamp = time.strftime("%Y-%m-%d;%H:%M:%S")
                    diff = abs(base_time - datetime.now())
                    output = f"{timestamp};{diff};{naming[3]};{data}"

                    # UI shows EVERYTHING
                    log_q.put(output)

                    # State detection
                    try:
                        stage_code = data.split(';')[1]
                        cycle_history.append(stage_code)
                        _, state = extract_columns(output, data_history=cycle_history[-5:])
                    except Exception:
                        state = None

                    if state and state != last_state:
                        print(f"[{battery_name}] 🔄 State changed → {state}")
                        last_state = state

                    save_file(
                        mode=2,
                        raw_data=output,
                        last_duration=duration,
                        stages_history=cycle_history[-5:],
                        naming=naming
                    )

                    duration = sum(
                        float(x) for x in output.split('$')[0].split(';')[-3].split(':')
                    )

                    if state == "finished":
                        print(f"[{battery_name}] 🏁 Finished")
                        break

                time.sleep(0.1)

    except Exception as e:
        print(f"[{battery_name}] ❌ Error: {e}")
        log_q.put(f"Error: {e}")


# ======================================================
# -------------------- UI TAB --------------------------
# ======================================================

class BatteryTab:
    def __init__(self, notebook, tab_name, com_ports):
        self.notebook = notebook
        self.tab_name = tab_name
        self.frame = ttk.Frame(notebook)
        notebook.add(self.frame, text=tab_name)

        self.info = {}
        self.com_ports = com_ports
        self.log_q = queue.Queue()
        self.stop_event = threading.Event()

        self._user_inputs(self.frame)

    def _user_inputs(self, root):
        self.info[self.tab_name] = {"Baud rate": 9600}
        btn_text = tk.StringVar(value="Confirmar datos")

        fields = [
            "Bateria",
            "Capacidad nominal",
            "Ciclo",
            "Ruta de folder",
            "Credenciales de base de datos"
        ]

        def on_submit():
            if btn_text.get() == "Confirmar datos":
                btn_text.set("Iniciar grabacion de datos")
                return

            self.info[self.tab_name]["COM port"] = dropdown_var.get()
            for f in fields:
                val = self.info[self.tab_name][f].get()
                if f == "Ruta de folder" and val == "":
                    val = os.getcwd()
                self.info[self.tab_name][f] = val

            for w in root.winfo_children():
                w.destroy()

            self._second_interface(root)

        ttk.Label(root, text="COM port:").grid(row=0, column=0)
        dropdown_var = tk.StringVar()
        ttk.Combobox(root, values=self.com_ports, textvariable=dropdown_var)\
            .grid(row=0, column=1)

        for i, name in enumerate(fields):
            ttk.Label(root, text=name).grid(row=i+1, column=0, sticky="w")
            entry = ttk.Entry(root, width=40)
            entry.grid(row=i+1, column=1)
            self.info[self.tab_name][name] = entry

        ttk.Button(root, textvariable=btn_text, command=on_submit)\
            .grid(row=len(fields)+1, column=0, columnspan=2, pady=10)

    def _second_interface(self, root):
        info = self.info[self.tab_name]
        self.notebook.tab(root, text=info["Bateria"])

        top = ttk.Frame(root)
        top.pack(fill=tk.X)
        for k, v in info.items():
            if isinstance(v, str):
                ttk.Label(top, text=f"{k}: {v}").pack(anchor="w")

        terminal = tk.Text(root, height=15)
        terminal.pack(fill=tk.BOTH, expand=True)

        naming = [
            info["Ruta de folder"],
            info["Bateria"],
            info["Capacidad nominal"],
            info["Ciclo"]
        ]

        t = threading.Thread(
            target=monitor_serial_thread,
            args=(
                {"port": info["COM port"], "naming": naming},
                self.log_q,
                self.stop_event
            ),
            daemon=True
        )
        t.start()

        self._update_terminal(terminal)

    def _update_terminal(self, terminal):
        while not self.log_q.empty():
            msg = self.log_q.get()
            terminal.insert(tk.END, msg + "\n")
            terminal.see(tk.END)
        terminal.after(100, self._update_terminal, terminal)


# ======================================================
# -------------------- MAIN APP ------------------------
# ======================================================

class App:
    def __init__(self, root):
        root.title("Icharger Multi-Battery Logger")
        notebook = ttk.Notebook(root)
        notebook.pack(fill="both", expand=True)

        com_ports = [f"COM{i}" for i in range(1, 21)]

        for i in range(1, 5):
            BatteryTab(notebook, f"Battery {i}", com_ports)


if __name__ == "__main__":
    root = tk.Tk()
    App(root)
    root.mainloop()
