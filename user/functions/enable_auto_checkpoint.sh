enable_auto_checkpoint() {
    # Create the LaunchAgent directory if it doesn't exist
    LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
    mkdir -p "$LAUNCH_AGENT_DIR"
    
    # Create the plist file
    PLIST_FILE="$LAUNCH_AGENT_DIR/com.unflab.autosave.plist"
    
    # Check if the LaunchAgent already exists
    if [ -f "$PLIST_FILE" ]; then
        # Just ensure it's loaded
        launchctl unload "$PLIST_FILE" 2>/dev/null
        launchctl load "$PLIST_FILE" 2>/dev/null
        return 0
    fi
    
    # Create logs directory if it doesn't exist
    LOG_DIR="$HOME/Library/Logs/UNFlab"
    mkdir -p "$LOG_DIR"
    
    # Create the plist content
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.unflab.autosave</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_PATH</string>
        <string>checkpointall</string>
    </array>
    <key>StartInterval</key>
    <integer>900</integer>
    <key>StartCalendarInterval</key>
    <array>
        <dict>
            <key>Minute</key>
            <integer>0</integer>
        </dict>
        <dict>
            <key>Minute</key>
            <integer>15</integer>
        </dict>
        <dict>
            <key>Minute</key>
            <integer>30</integer>
        </dict>
        <dict>
            <key>Minute</key>
            <integer>45</integer>
        </dict>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/autosave.err</string>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/autosave.out</string>
    <key>CFBundleName</key>
    <string>UNFlab Autosave</string>
    <key>CFBundleIdentifier</key>
    <string>com.unflab.autosave</string>
    <key>CFBundleDisplayName</key>
    <string>UNFlab Autosave</string>
    <key>CFBundleGetInfoString</key>
    <string>UNFlab Automatic Save Service</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>$HOME</string>
    </dict>
    <key>WorkingDirectory</key>
    <string>$HOME</string>
    <key>KeepAlive</key>
    <false/>
    <key>ThrottleInterval</key>
    <integer>60</integer>
</dict>
</plist>
EOF

    # Load the LaunchAgent
    launchctl unload "$PLIST_FILE" 2>/dev/null
    launchctl load "$PLIST_FILE" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        display_notification "Autosave Enabled" "UNFlab will autosave your work every 15 minutes."
    else
        display_notification "Autosave is Disabled." "Failed to enable autosave. Please check permissions."
        return 1
    fi
}

disable_auto_checkpoint() {
    PLIST_FILE="$HOME/Library/LaunchAgents/com.unflab.autosave.plist"
    
    # Unload the LaunchAgent if it exists
    if [ -f "$PLIST_FILE" ]; then
        launchctl unload "$PLIST_FILE" 2>/dev/null
        rm "$PLIST_FILE"
        display_notification "Autosave Disabled" "UNFlab autosave has been disabled."
    fi
}

