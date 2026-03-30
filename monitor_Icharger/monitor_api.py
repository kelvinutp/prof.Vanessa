import serial
import time
import os
from datetime import datetime
import glob
from collections import Counter
import serial.tools.list_ports
import traceback
import threading
import queue

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

app = FastAPI(title="iCharger Monitor API")

# Allow CORS for flutter local web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global State
batteries = {}  # { "battery_id": { ...status...} }
threads = {}    # { "battery_id": threading.Thread }
queues = {}     # { "battery_id": queue.Queue }
stop_events = {}

# ======================================================
# ---------------- DATA PROCESSING ---------------------
# ======================================================

def extract_columns(data, delimiter=';', data_history=None):
    if data_history is None:
        data_history = []
    
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
# ---------------- SERIAL MONITOR ----------------------
# ======================================================

def monitor_serial_port(battery_id, naming, port='COM3', baudrate=9600, timeout_seconds=60):
    ciclo=int(naming[2])
    stop_event = stop_events[battery_id]
    q = queues[battery_id]
    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            
            base_time=datetime.now()
            last_activity_time = time.time()
            cycle_history=[]
            stage='initializing'

            manipulable_cycle = ciclo

            batteries[battery_id]["status"] = "monitoring"
            
            while not stop_event.is_set():
                timestamp = time.strftime("%Y-%m-%d;%H:%M:%S")
                
                if ser.in_waiting > 0:
                    data = ser.readline().decode('utf-8', errors='ignore').strip()
                    if data:
                        diff=abs(base_time-datetime.now())
                        cycle_history.append(data.split(';')[1])
                        output = f"{timestamp};{diff};{manipulable_cycle};{data}"
                        
                        modified_data, current_state = extract_columns(output, data_history=cycle_history[-5:])

                        if cycle_history[-5:]==['4','4','1','1','1']:
                            manipulable_cycle+=1
                            base_time=datetime.now()
                        elif cycle_history[-5:]==['6','6','6','6','6']:
                            break
                        
                        # Update global status
                        try:
                            # 2026-03-30;timestamp;diff;cycle;state;voltage;current;capacity;etc
                            parts = modified_data.split(';')
                            batteries[battery_id].update({
                                "state": current_state,
                                "voltage": parts[5] if len(parts) > 5 else "0",
                                "current": parts[6] if len(parts) > 6 else "0",
                                "capacity": parts[7] if len(parts) > 7 else "0",
                                "last_update": timestamp
                            })
                        except Exception as e:
                            pass
                        
                        q.put(output)
                        last_activity_time = time.time()
                else:
                    pass
                
                if time.time() - last_activity_time > timeout_seconds:
                    batteries[battery_id]["status"] = "timeout"
                    break
                time.sleep(0.1)

    except serial.SerialException as e:
        batteries[battery_id]["status"] = "error"
        batteries[battery_id]["error_msg"] = str(e)
    finally:
        if batteries[battery_id]["status"] == "monitoring":
            batteries[battery_id]["status"] = "stopped"

# ======================================================
# ---------------- API ENDPOINTS -----------------------
# ======================================================

class StartMonitorRequest(BaseModel):
    battery_id: str
    port: str
    baudrate: int
    bateria: str
    capacidad: str
    ciclo: str
    folder: str

@app.get("/ports")
def get_ports():
    ports = serial.tools.list_ports.comports()
    return [{"device": p.device, "description": p.description} for p in ports]

@app.get("/batteries")
def get_all_batteries():
    return batteries

@app.post("/monitor/start")
def start_monitor(req: StartMonitorRequest):
    if req.battery_id in threads and threads[req.battery_id].is_alive():
        raise HTTPException(status_code=400, detail="Battery ID already monitoring.")
    
    naming = [req.folder, req.bateria, req.capacidad, req.ciclo]
    
    stop_events[req.battery_id] = threading.Event()
    queues[req.battery_id] = queue.Queue()
    
    batteries[req.battery_id] = {
        "battery_id": req.battery_id,
        "bateria": req.bateria,
        "capacidad": req.capacidad,
        "ciclo": req.ciclo,
        "port": req.port,
        "baudrate": req.baudrate,
        "status": "starting",
        "state": "unknown",
        "voltage": "0",
        "current": "0",
        "capacity": "0",
        "error_msg": "",
        "last_update": ""
    }
    
    t = threading.Thread(
        target=monitor_serial_port,
        args=(req.battery_id, naming, req.port, req.baudrate),
        daemon=True
    )
    threads[req.battery_id] = t
    t.start()
    
    return {"message": "Started tracking"}

@app.post("/monitor/stop/{battery_id}")
def stop_monitor(battery_id: str):
    if battery_id in stop_events:
        stop_events[battery_id].set()
        return {"message": "Stopping tracking"}
    raise HTTPException(status_code=404, detail="Not tracking this battery.")

if __name__ == "__main__":
    print("Starting Headless iCharger Monitor API on port 8000...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
