import subprocess
import sys

required_packages=['pyserial==3.5','serial==0.0.97','psycopg2-binary']

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
