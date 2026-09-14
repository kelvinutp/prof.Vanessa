#!/usr/bin/env python3
import sys
import subprocess
import platform
import shutil
import os

def log(level, message):
    colors = {
        "INFO": "\033[94m",
        "SUCCESS": "\033[92m",
        "WARNING": "\033[93m",
        "ERROR": "\033[91m",
        "RESET": "\033[0m"
    }
    color = colors.get(level, "")
    reset = colors["RESET"]
    print(f"{color}[{level}] {message}{reset}")

def check_command(cmd):
    return shutil.which(cmd) is not None

def run_cmd(cmd_list):
    try:
        # Use shell=True on Windows if flutter/git are bat/cmd scripts
        use_shell = True if platform.system() == "Windows" else False
        result = subprocess.run(
            cmd_list, 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True, 
            check=True, 
            shell=use_shell
        )
        return True, result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return False, e.stderr.strip()

def main():
    system = platform.system()
    log("INFO", f"Starting Lab Control Suite Pre-flight Check on {system} ({platform.machine()})")
    
    pending_items = []

    # 1. Check Flutter Installation
    if check_command("flutter") or os.path.exists("flutter/bin/flutter"):
        success, version_output = run_cmd(["flutter", "--version"])
        if success:
            log("SUCCESS", f"Flutter SDK found: {version_output.splitlines()[0]}")
        else:
            log("WARNING", "Flutter found but failed to query version.")
    else:
        log("ERROR", "Flutter SDK is NOT installed or not added to system PATH.")
        pending_items.append("Flutter SDK (Download & install from https://flutter.dev/docs/get-started/install)")

    # 2. Check Dart SDK Installation
    if check_command("dart"):
        log("SUCCESS", "Dart SDK is present.")
    else:
        log("ERROR", "Dart SDK is missing (usually bundled with Flutter).")
        pending_items.append("Dart SDK")

    # 3. Check Git (Required by Flutter for package dependency resolution)
    if check_command("git"):
        log("SUCCESS", "Git version control is present.")
    else:
        log("ERROR", "Git is NOT installed or not in PATH.")
        pending_items.append("Git (Required for fetching Flutter packages)")

    # 4. Check project configuration and run pub get if pubspec.yaml exists
    if os.path.exists("pubspec.yaml"):
        log("INFO", "Found pubspec.yaml. Verifying project dependencies...")
        if check_command("flutter"):
            success, output = run_cmd(["flutter", "pub", "get"])
            if success:
                log("SUCCESS", "All Flutter libraries and packages successfully fetched.")
            else:
                log("ERROR", f"Failed to resolve libraries via 'flutter pub get'. Output:\n{output}")
                pending_items.append("Valid pubspec.yaml dependencies resolution (Check internet connection or package versions)")
        else:
            log("WARNING", "Skipped dependency fetching because Flutter SDK is missing.")
            pending_items.append("Run 'flutter pub get' manually after installing Flutter")
    else:
        log("WARNING", "pubspec.yaml not found in current directory. Make sure you run this script from the project root.")

    # 5. Summary and Pending Logging
    print("\n" + "=" * 60)
    if not pending_items:
        log("SUCCESS", "All pre-flight checks passed successfully! Your environment is ready.")
        print("=" * 60)
        sys.exit(0)
    else:
        log("WARNING", "Environment setup is INCOMPLETE. The following components are pending:")
        print("=" * 60)
        for idx, item in enumerate(pending_items, 1):
            print(f"  {idx}. [PENDING] -> {item}")
        print("=" * 60)
        log("ERROR", "Please resolve the pending items above before building or running the Flutter app.")
        sys.exit(1)

if __name__ == "__main__":
    main()