import ctypes
import serial
import time
import serial.tools.list_ports
from collections import Counter

# MessageBox parameters:
# 0 = OK button only
# "Supervisor program successfully opened" = message text
# "Supervisor" = title of the message box
ctypes.windll.user32.MessageBoxW(0, "Supervisor program successfully opened", "Supervisor", 0)

# Function to extract selected columns
def extract_columns(data, selected_columns,delimiter=';'):
    '''
    Extracts the intended data given the indeces in selected_columns
    Determines which is the current state type.
    '''
    columns = data.split(delimiter)  
    result = [str(int(columns[i])/1000) if i==5 else columns[i] for i in selected_columns]
    if result[1]=='1':
        estado='charging'
    elif result [1]=='2':
        estado='discharging'
    elif result [1]=='4':
        estado='rest'
    elif result[1]=='6':
        estado='finished'
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

def save_file(estado,bateria,capacidad,ciclo,data):
    '''
    Function for saving the data file (.csv)
    By data analisis, each current state is compared to the previous four (4) states. 
    When the 5 states changes, then it's certain the battery power state has changed
    '''
    estados_pasados.append(estado)
    if len(estados_pasados)==1: #data collection is beginnning
        print("saving data starting")
        #log_file = open(f"Data_original_{bateria}_{capacidad}_{ciclo}_{int(time.time())}.txt", "w")
        #log_file.write('datetime;voltage[V];current[mA];capacity[mAh]'+'\n')#colocando los encabezados de las columnas
    elif len(estados_pasados)>4:
        if all(x==estado for x in estados_pasados):
            file_name=f"{bateria}{estado[0]}_{capacidad}_{ciclo}.csv"
        else:
            most_common_elem, count = Counter(estados_pasados).most_common(1)[0]
            file_name:f"{bateria}{most_common_elem[0]}_{capacidad}_{ciclo}.csv"
        estados_pasados.pop(0)
    #log_file.write(f"{data}"+'\n')#write the data in the files
    #log_file.flush()


def monitor_serial_port(bateria,capacidad,ciclo,port='COM3', baudrate=9600, log_to_file=False, timeout_seconds=60):
    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            print(f"Monitoring {port} at {baudrate} baud. Timeout after {timeout_seconds} seconds of inactivity.")

            if log_to_file:
                log_file = open(f"data_original_{bateria}_{capacidad}_{ciclo}.csv", "w")
                log_file.write('datetime;voltage[V];current[mA];capacity[mAh]'+'\n')#colocando los encabezados de las columnas
                log_file.flush()
            else:
                log_file = None

            last_activity_time = time.time()
            estados_pasados=[]
            
            while True:
                if ser.in_waiting > 0:
                    data = ser.readline().decode('utf-8', errors='ignore').strip()
                    if data:
                        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                        output = f"{timestamp};{data}"
                        print(output)
                        
                        data,estado=extract_columns(output,columns_to_extract)
                        if estados_pasados==['finished','finished','finished','finished']:
                            print("finished cicles \nclosing program")
                            break
                        elif log_to_file:
                            save_file(estado,1,1,1,data)
                    
                        
                        if log_file:
                            log_file.write(data + '\n')
                            log_file.flush()
                        last_activity_time = time.time()

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

if __name__ == "__main__":
    # List available COM ports before starting the data reading
    b=list_com_ports()
    confirm=False
    while not(confirm):
        a=int(input("Seleccione el numero de puerto que se va a supervisar (puerto copia de VirtualSerialPort: "))
        print("ha seleccionado el puerto: ",b[a])
        c=input("Confirme que el puerto seleccionado es correcto (Y/N): ")
        if c.upper()=="Y":
            confirm=True
    
    # Start reading serial data
    monitor_serial_port(b[a],log_to_file=True,timeout_seconds=10)
    time.sleep(5)
