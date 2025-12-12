import time
from serial.tools import list_ports
import threading
import serial

# ------------------------------
# Serial reader function
# ------------------------------
def start_serial_reader(port, baudrate=9600, callback=None):
    """Start an independent serial reader that runs in background."""
    
    def reader():
        try:
            ser = serial.Serial(port, baudrate, timeout=1)
            print(f"[+] Started reader on {port}")
        except Exception as e:
            print(f"[!] Failed to open {port}: {e}")
            return

        while True:
            try:
                data = ser.readline().decode(errors="ignore").strip()
                if data:
                    if callback:
                        callback(port, data)
                    else:
                        print(f"[{port}] {data}")
            except Exception as e:
                print(f"[!] Error on {port}: {e}")
                break

        ser.close()
        print(f"[-] Reader stopped on {port}")

    t = threading.Thread(target=reader, daemon=True)
    t.start()
    return t

# -----------------------------------------
# Interactive console: user activates readers
# -----------------------------------------
if __name__ == "__main__":
    active_ports = {}   # keep track of started readers

    print("=== Serial Reader Console ===")
    print("Commands:")
    print("   start <port>  → Start reading from serial port")
    print("   all           → Shows all available COM ports")
    print("   list          → List active ports")
    print("   quit          → Exit program")
    print("=============================")
    
    while True:
        try:
            cmd = input("> ").strip()
        except KeyboardInterrupt:
            print("\nExiting.")
            break

        if cmd == "":
            continue

        # --- start command ---
        if cmd.startswith("start "):
            port = cmd.split(" ", 1)[1]

            if port in active_ports:
                print(f"[!] Port {port} is already running.")
                continue

            # Start the reader
            t = start_serial_reader(port)
            active_ports[port] = t 
            continue

        # --- list active ports ---
        if cmd == "list":
            if not active_ports:
                print("[*] No active serial readers.")
            else:
                print("Active ports:")
                for p in active_ports:
                    print(f"  - {p}")
            continue
        
        # --- all ----
        if cmd =="all":
            ports = list_ports.comports()
            for p in ports:
                print(p.device)
            continue

            
        # --- quit ---
        if cmd == "quit":
            print("Exiting program.")
            break

        print("[!] Unknown command. Try: start <port>, all, list, quit")
