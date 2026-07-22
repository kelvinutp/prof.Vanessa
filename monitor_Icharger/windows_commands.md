## Windows scripts
### Finding file
save as .bat file
```
@echo off
set "search_pattern=*data_original*"
set "output_file=found_files.txt"

echo Searching for files containing "%search_pattern%"...
:: /S: subfolders, /B: absolute path, /A-D: exclude directory names themselves
dir /S /B /A-D "%search_pattern%" > "%output_file%"

echo Search complete. Results saved to %output_file%
pause
```

### checking headers of CSV files
```
@echo off
setlocal enabledelayedexpansion

set "input_file=found_files.txt"
set "error_log=header_errors.txt"
set "first_file=1"

:: Clear previous error log
if exist "%error_log%" del "%error_log%"

echo Starting header validation...
echo -------------------------------

for /F "usebackq delims=" %%A in ("%input_file%") do (
    :: Read only the first line (the header) of the current file
    set "current_header="
    set /p current_header=<"%%A"

    if "!first_file!"=="1" (
        set "master_header=!current_header!"
        set "first_file=0"
        echo Master Header set from: %%~nxA
    ) else (
        if "!current_header!"=="!master_header!" (
            echo [OK] %%~nxA
        ) else (
            echo [MISMATCH] %%~nxA
            echo %%A >> "%error_log%"
        )
    )
)

echo -------------------------------
if exist "%error_log%" (
    echo Validation failed for some files. Check %error_log% for details.
) else (
    echo Success! All headers are identical and in the same order.
)

pause
```
### copying files into single directory

```
@echo off
set "input_file=found_files.txt"
set "dest_folder=C:\Extracted_Data"

:: Create destination if it doesn't exist
if not exist "%dest_folder%" mkdir "%dest_folder%"

echo Starting copy process...
:: /F "delims=" handles file paths with spaces correctly
for /F "usebackq delims=" %%A in ("%input_file%") do (
    echo Copying: %%A
    copy "%%A" "%dest_folder%\"
)

echo.
echo All files have been copied to %dest_folder%
pause
```

### uploading data to postgredB
```
@echo off
setlocal enabledelayedexpansion

set "input_file=found_files.txt"
set "db_host=localhost"
set "db_port=5432"
set "db_name=your_database"
set "db_user=postgres"
set "table_name=raw_data_imports"

set /p first_path=<"%input_file%"
set /p headers=<"%first_path%"

psql -h %db_host% -p %db_port% -U %db_user% -d %db_name% -c "CREATE TABLE IF NOT EXISTS %table_name% (source_file_path TEXT);"
for %%H in (%headers%) do (
    psql -h %db_host% -p %db_port% -U %db_user% -d %db_name% -c "ALTER TABLE %table_name% ADD COLUMN IF NOT EXISTS %%H TEXT;"
)

for /F "usebackq delims=" %%A in ("%input_file%") do (
    echo Processing: %%A
    psql -h %db_host% -p %db_port% -U %db_user% -d %db_name% -c "CREATE TEMP TABLE tmp_table (LIKE %table_name% INCLUDING ALL); ALTER TABLE tmp_table DROP COLUMN source_file_path; COPY tmp_table FROM '%%A' WITH (FORMAT csv, HEADER true); INSERT INTO %table_name% SELECT '%%A', * FROM tmp_table; DROP TABLE tmp_table;"
)

pause
```
