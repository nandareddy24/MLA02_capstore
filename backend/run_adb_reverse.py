"""Keeps ADB reverse port forwarding alive continuously in the background."""
import time
import subprocess

adb = r"C:\Users\DELL\AppData\Local\Android\Sdk\platform-tools\adb.exe"

while True:
    try:
        subprocess.run([adb, "reverse", "tcp:8000", "tcp:8000"], capture_output=True)
    except Exception:
        pass
    time.sleep(3)
