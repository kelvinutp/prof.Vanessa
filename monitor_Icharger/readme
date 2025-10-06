Codes and sample data related to Icharger battery cycles

# Usage

[Reading Data from serial port](./monitor DataExplorer.py)
This programs reads data from the data serial port. It has integrated the following functions.
1. Extract columns: This functions read the original data and chooses which to extract and save to the CSV and postgreDB
The current data structure is as follows:
- 0: date (extracted from the system)
- 1: time (extracted from the system)
- 2: cycle_time (processed by the script)
- 4: battery_state_cycle (1: charging, 2:discharing, 4:rest, 6:finished)
- 7: Voltage (read from COM port) originally in mV.
- 8: current (read from COM port) originally in cA.
-17: capacity (read from COM port) originally in mAh.

2. list_com_port: reads all the available com ports and shows the user and index list to choose the correct port to read data from.

3. insert_cycle_data: takes the data and inserts in into de postgreDB

4. save_file: takes the data and saves it into the the correspongind cycle file (charging.csv, discharging.csv, rest.csv, finished.csv)

5. monitor_serial_port: read the data from the COM port and add the datetime (read from the system)

Naming scheme <ins>{battery}{charging/discharging/rest}_{battery nominal capacity}_{cycle number}.csv</ins>

[Installing requirements](./requirements_installation.py)
<ins>Only to run once</ins>
Installs the required python libraries for the [monitor DataExplorer.py](./monitor DataExplorer.py) to work

[csv_to_DP](./csv_to_DP.py)
<ins>To run only when there's recorded data **NOT** from the [monitor DataExplorer.py](./monitor DataExplorer.py)</ins>
This program reads the data (in .csv or .txt) that was <ins> **NOT**</ins> recorded from the [monitor DataExplorer.py](./monitor DataExplorer.py)
It has the following integrated functions
1. order_columns: looks for the row that have the headers and determines the columns data order.

2. data_reading: reads all the data in the .csv/.txt file, saves it into the postgreDB and determines 
- the correct order
- the cycle_state (from the file name)
- date (from the file name)
- nominal capacit (from the file name)
- cycle number (from the file name)

3. create_tables_and_triggers: creates the tables and triggers to save data into the postgreDB

4. insert_cycle_data: save the data in the correct table within the postgreDB
