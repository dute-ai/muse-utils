tell application "Terminal"
    do script "cd ~/treadmill-ctl && ./venv/bin/python scan.py 20; echo DONE-MARKER"
    return id of window 1
end tell
