Codes and sample data related to Icharger battery cycles
# Devices and programs
## Devices
Testing devices
1. [iCharger 106B (Junsi) charger/discharger](https://www.icharger.pl/manuals/106B_en.pdf) 

2. [iCharger 208 (Junsi) charger/discharger Datasheet](https://www.icharger.pl/manuals/208B_en.pdf)

## Ｓoftware

1. [Data Explorer](https://www.nongnu.org/dataexplorer/download.html)

## Raw Data format from Icharger

This data was obtained from reading the serial port and inserting the data directly into a CSV file
`
$1;1;;12000;4190;7;0;0;0;0;0;0;328;0;6;40
`\
Sample data can be viewed from [this file](./test_data/data.csv)
<br>Splitting it by ";" the following data structure was found:

|Index|Value|Description|
| --- | --- | --- |
|0|`$1` |Unknown. It was used to determine the beggining of the data string|
|1|`1`|Baterry stage. This value could take any of the following values: <br>1: Charging <br>2: Discharging <br>4: Resting <br>6: Finished
|2| | Empty|
|3|`12000`|Supplied voltage|
|4|`4190`|Applied voltage to the battery (mV). For the tests in this repository it varied from 3.0 to 4.2V
|5|`7`|Applied current to the battery (cA). For the tests in this repository it varied from 0 to 50 mA
|6 - 11|`0;0;0;0;0;0`|Corresponds to the Cell Voltage. This devices is able to manage up to 8 batteries|
|12|`328`|Unknown|
|13|`0`|Unknown|
|14|`6`|Battery capacity in (mAh). For the tests in this repository, this values rests itself in every battery stage.
|15|`40`|Unknown|

Pending parameters to discover/establish relationship. This parameters are supplied by the 
- Temperature
- Power
- Energy

# Requirements to run this programas
- Python 3. [Link to download](https://www.python.org/downloads/)
- PostgreDB [Link to download](https://www.postgresql.org/download/windows/)

## Programs and functionalities

|Recommende order to run program|Program|Description|
|---|---|---|
|0|[requirements_installation.py](./requirements_installation.py)|Installs the python libraries needed to run the following programs<br>**Only need to run once**|
|1|[csv_to_DP.py](./csv_to_DP.py)|Creates postgreDB tables, reads data from CSV files into the database|
|2 <br>(no user interface)|[monitor DataExplorer.py](./monitor%20DataExplorer.py)|Reads the data from the Serial COM port and saves it into csv files. If DB credentials provided, it can also saves the data into the database <br>**This program has no graphical interface**|
|2 <br> (with user interface)|[monitor GUI.py](./monitor%20GUI.py)|Same functionalities as monitor DataExplorer, but added graphical user interface (GUI)|
|For testing purposes|[txt2COM.py](./txt2COM.py)|This programs helps to read the data from a txt or csv file and feeds it through a COM port to test the functionality of the monitor DataExplorer and/or monitor GUI

### Summary Explanation for the provided programs

#### [Requirements_installation.py](./requirements_installation.py)
This programs checks if the needed libraries ares installed in the system, if not, they're installed using PIP command.

Needed libraries and their use
|Library|Use case|
|---|---|
|Serial|Used for serial communication and listing serial ports|
|psycopg2-binary|Using for stablishing communication with the postgreDB|
|pandas|Used for large data processing|
|matplotlib|Used for generating graphics|

#### [csv_to_DP.py](./csv_to_DP.py)
This program is used to generate the tables in the database to store the data. Also it reads the data from any CSV file and inserts it into the database when needed.

Generated tables
- charging
- dicharging
- rest
- all_data

Every table will have the following columns
- date
- time (this is a stopwatch like, used to measure the duration of the charging stage)
- voltage
- current
- capacity
- cycle number
- nominal_capacity
- mode (only on all_data table)

#### [monitor DataExplorer.py](./monitor%20DataExplorer.py)
**This program has no user graphical interface (GUI)**

Reads the data directly from the com port and saves it into a CSV file in the local computer for the desired folder path and local postgreDB (if credential are provided).

#### [monitor GUI.py](./monitor%20GUI.py)
Reads the data directly from the com port and saves it into a CSV file in the local computer for the desired folder path and local postgreDB (if credential are provided).

# Extracting data from postgreDB to a file format
## if using docker container

```
docker exec -t <container_name> pg_dump -U <user> <databasen_name> > <file_name>.sql #This creates a SQL file from the data in the database

docker cp <container_name>:/<file_name>.sql ./<new_file_name>.sql #This copies the data **outside** the container
```