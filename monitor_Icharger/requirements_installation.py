import subprocess
import sys
import platform #to check the working operating system
import colorama #to paint the output on the terminal

colorama.init(autoreset=True)

required_packages=['pyserial',
                    'serial',
                    'psycopg2-binary',
                    'ipython-sql',
                    'pandas',   
                    'matplotlib']

def install_package(package):
    """Installs the package using pip"""
    subprocess.check_call([sys.executable, '-m', 'pip','install',package])

def check_and_install_dependencies(packages):
    """Checks if packages are installed, installs them if not"""
    for package in packages:
        try:
            __import__(package.split('==')[0])
            print(f"{package} is alreday installed")
        except ImportError:
            print(f'{package} not found. Installing...')
            install_package(package)
            print(f'{package} has been installed.')
    return

def check_dependencies(packages):
    """Checks if packages are installed, installs them if not"""
    for package in packages:
        if platform.system()=="Windows":
            command=f'pip list | find /I"{package}"'
        else:
            command=f"pip list | grep {package}"
        try:
            result = subprocess.run(
                command,
                shell=True,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            print(f"{package} installed correctly")
        except subprocess.CalledProcessError as e:
            print(f"{colorama.Fore.RED}Command failed with error:\n {e.stderr}")

    return

def db_check():
    #checking for postgreDB
    try:
        subprocess.run(["psql", "--version"], check=True, capture_output=True)
        print("PostgreSQL client (psql) is installed.")
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"{colorama.Fore.RED}PostgreSQL client (psql) is not found in the system's PATH.")
    
    #checking com0com for creating a pair of virtual COMports
    try:
        output = subprocess.run(['driverquery|find \\I "com0com"'], shell=True, check=True, capture_output=True)
        print(f'com0com in {output.lower()}')
    except Exception:
        print(f'{colorama.Fore.RED}COM0COM is not installed, not being able to connect to DataExplorer at the moment')
    return

if __name__=='__main__':
    # check_and_install_dependencies(required_packages)
    print("Checking the correct installation")
    # check_dependencies(required_packages)
    db_check()
    input("Presione la tecla ENTER para salir")