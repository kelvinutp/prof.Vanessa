import ctypes
import serial
import time
import serial.tools.list_ports


# MessageBox parameters:
# 0 = OK button only
# "Supervisor program successfully opened" = message text
# "Supervisor" = title of the message box
ctypes.windll.user32.MessageBoxW(0, "Supervisor program successfully opened", "Supervisor", 0)

# Function to extract selected columns
def extract_columns(data, selected_columns,delimiter=';'):
    """
    Extracts the specified columns from the input data.
    Assumes that data is space or comma-separated.
    
    :param data: The raw data (e.g., CSV row or space-separated row).
    :param selected_columns: List of column indices (1-based index).
    :return: A list of extracted values from the selected columns.
    """
    columns = data.split(delimiter)  # Change the delimiter if needed (space-separated or tab-separated)
    # Convert 1-based indices to 0-based for Python list indexing
    # selected_columns= [columns[i - 1] for i in selected_columns]
    volt=int(columns[selected_columns[0]-1])/1000 #voltage in Volts
    amp=int(columns[selected_columns[1]-1]) #current in mA
    cap=int(columns[selected_columns[2]-1]) #capacity in mAh

    # Join the selected columns back into a string and encode it back into bytes
    result = delimiter.join(selected_values)  # Join by the same delimiter
    return result #return the data as string

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

def monitor_serial_port(port='COM3', baudrate=9600, log_to_file=False, timeout_seconds=60):
    try:
        with serial.Serial(port, baudrate, timeout=1) as ser:
            print(f"Monitoring {port} at {baudrate} baud. Timeout after {timeout_seconds} seconds of inactivity.")

            if log_to_file:
                log_file = open(f"log_{port}_{int(time.time())}.txt", "w")
                log_file.write('datetime;voltage[V];current[mA];capacity[mAh]'+'\n')#colocando los encabezados de las columnas
                log_file.flush()
            else:
                log_file = None

            last_activity_time = time.time()

            while True:
                if ser.in_waiting > 0:
                    data = ser.readline().decode('utf-8', errors='ignore').strip()
                    if data:
                        timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
                        
                        selected_columns = [5,6,7]  # Adjust indices based on your needs
                        extracted_data = extract_columns(data, selected_columns)
                        
                        output = f"{timestamp};{extracted_data}"
                        print(output)
                        if log_file:
                            log_file.write(output + '\n')
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
