import serial
import time

# Configuration
com_port = 'COM8'       # Change to your COM port
baud_rate = 115200        # Change to your baud rate
# file_path = r'C:\Users\user\Desktop\prof.Vanessa\monitor_Icharger\data_original_2_3800_1.csv'  # Path to your text file
file_path = r'C:\Users\user\Desktop\prof.Vanessa\monitor_Icharger\test_data\data.csv'  # Path to your text file

# Open serial port
ser = serial.Serial(com_port, baud_rate, timeout=1)
time.sleep(2)  # Wait for port to initialize

# Read file and write to COM port
with open(file_path, 'r') as file:
    for line in file.readlines()[:500]:
        print((';'.join(line.strip().split(";")) + '\n'))
        ser.write((';'.join(line.strip().split(";")) + '\n').encode())
        time.sleep(0.1)  # Optional delay between lines

ser.close()
