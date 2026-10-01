on run argv
    set winId to (item 1 of argv) as integer
    tell application "Terminal"
        return contents of tab 1 of window id winId
    end tell
end run
