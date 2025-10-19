import serial
import time

# Configuration
com_port = 'COM3'       # Change to your COM port
baud_rate = 9600        # Change to your baud rate
file_path = r'C:\Users\user\Desktop\prof.Vanessa\monitor_Icharger\test_data\data.csv'  # Path to your text file

# Open serial port
ser = serial.Serial(com_port, baud_rate, timeout=1)
time.sleep(2)  # Wait for port to initialize

# Read file and write to COM port
with open(file_path, 'r') as file:
    for line in file:
        print(line)
        ser.write((line.strip() + '\n').encode())
        time.sleep(0.1)  # Optional delay between lines

ser.close()
