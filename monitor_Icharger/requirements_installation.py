import subprocess
import sys

required_packages=[
    et_xmlfile==2.0.0,
    future==1.0.0,
    iso8601==2.1.0,
    numpy==2.3.1,
    openpyxl==3.1.5,
    packaging==25.0,
    pandas==2.3.0,
    pdf2image==1.17.0,
    pillow==11.3.0,
    psutil==7.0.0,
    pyodbc==5.2.0,
    pyserial==3.5,
    pytesseract==0.3.13,
    python-dateutil==2.9.0.post0,
    pytz==2025.2,
    PyYAML==6.0.2,
    serial==0.0.97,
    six==1.17.0,
    tzdata==2025.2,
    watchdog==6.0.0
    ]
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

if __name__=='__main__':
    check_and_install_dependencies(required_packages)
