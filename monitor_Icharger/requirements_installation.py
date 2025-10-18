import subprocess
import sys
import time

RED = "\033[31m"
RESET = "\033[0m"

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
        try:
            result = subprocess.run(
                f"pip list | grep {package}",
                shell=True,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            print(f"{package} installed correctly")
        except subprocess.CalledProcessError as e:
            print(f"{RED}Command failed with error:\n {e.stderr}{RESET}")

    return

def db_check():
    try:
        subprocess.run(["psql", "--version"], check=True, capture_output=True)
        print("PostgreSQL client (psql) is installed.")
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(f"{RED}PostgreSQL client (psql) is not found in the system's PATH.{RESET}")
    return

if __name__=='__main__':
    check_and_install_dependencies(required_packages)
    print("Checking the correct installation")
    check_dependencies(required_packages)
    db_check()
    input("Presione la tecla ENTER para salir")