enable_auto_checkpoint() {
    log_message "(BEGIN ENABLE_AUTO_CHECKPOINT)"
    
    # Only run in statusbar mode (when no other mode flags are set)
    if [ "$navbar" = true ] || [ "$progressbar" = true ] || [ "$droplet" = true ]; then
        log_message "Skipping enable_auto_checkpoint - not in statusbar mode (navbar=$navbar, progressbar=$progressbar, droplet=$droplet)"
        return 0
    fi
    
    log_message "Running enable_auto_checkpoint in statusbar mode"
    
    # Create the LaunchAgent directory if it doesn't exist
    LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
    mkdir -p "$LAUNCH_AGENT_DIR"
    
    # Define the plist file path
    PLIST_FILE="$LAUNCH_AGENT_DIR/com.unflab.autosave.plist"
    
    # Store the plist content in a variable
    PLIST_CONTENT='<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.unflab.autosave</string>

        <key>ProgramArguments</key>
        <array>
            <string>'"$BASH_SCRIPT_PATH"'</string>
            <string>checkpointall</string>
            <string>--silent</string>
        </array>

        <key>StartInterval</key>
        <integer>600</integer>

        <key>RunAtLoad</key>
        <true/>

        <key>StandardOutPath</key>
        <string>/tmp/unflab.out</string>
        <key>StandardErrorPath</key>
        <string>/tmp/unflab.err</string>
    </dict>
</plist>'

    # Track if we made any changes
    local made_changes=false

    # Check if the LaunchAgent exists and compare contents
    if [ -f "$PLIST_FILE" ]; then
        log_message "Autocheckpoint plist file found."
        CURRENT_CONTENT=$(cat "$PLIST_FILE")
        if [ "$CURRENT_CONTENT" != "$PLIST_CONTENT" ]; then
            log_message "Updating plist file."
            echo "$PLIST_CONTENT" > "$PLIST_FILE"
            log_message "Reloading service."
            launchctl unload "$PLIST_FILE" 2>/dev/null
            launchctl load "$PLIST_FILE" 2>/dev/null
            made_changes=true
        else
            log_message "Autocheckpoint service is up to date."
        fi
    else
        log_message "Autocheckpoint plist file not found, creating new file."
        echo "$PLIST_CONTENT" > "$PLIST_FILE"
        made_changes=true
    fi

    # Check if the service is loaded
    log_message "Checking if autocheckpoint service is loaded."
    if ! launchctl list | grep -q "com.unflab.autosave"; then
        log_message "Service not loaded, loading now"
        launchctl load "$PLIST_FILE" 2>/dev/null
        made_changes=true
    fi
    
    if [ $? -eq 0 ]; then
        log_message "Autosave service enabled successfully"
        if [ "$made_changes" = true ]; then
            display_notification "Autosave Enabled" "UNFlab will autosave your work every 15 minutes."
        fi
    else
        log_message "Failed to enable autosave service"
        display_notification "Autosave is Disabled." "Failed to enable autosave. Please check permissions."
        return 1
    fi
    
    log_message "(END ENABLE_AUTO_CHECKPOINT)"
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

