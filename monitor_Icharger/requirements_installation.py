import subprocess
import sys
import platform

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

def install_chocolatey(): 
    """Installs chocolatey package manager in windows machines
    """    
    command = r"""powershell -NoProfile -ExecutionPolicy Bypass -Command "Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" """
    try:
        subprocess.run(
            command,
            shell=True,
            check=True
        )
        print("Chocolatey installed successfully.")
    except subprocess.CalledProcessError as e:
        print("Failed to install Chocolatey.")

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
    if platform.system()=='Windows':
        try:
            subprocess.run(
                ["choco", "-v"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=True
            )
        except:
            install_chocolatey()
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
        if platform.system()=="Windows":
            subprocess.run(["choco", "install", "postgresql", "-y"], check=True)
            db_check() #checks if the postgredb was installed
    return

if __name__=='__main__':
    check_and_install_dependencies(required_packages)
    print("Checking the correct installation")
    check_dependencies(required_packages)
    db_check()
    input("Presione la tecla ENTER para salir")