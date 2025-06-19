# Function to log messages
log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$message" >> "$LOG_FILE"
    
    # Echo to console if debug mode is enabled
    if [ "$DEBUG_MODE" = true ]; then
        echo "$message"
    fi
}

# Function to handle errors using Platypus ALERT format
handle_error() {
    echo "$1"
    log_message "ERROR: $1"

    # Skip notification if in silent mode
    if [ "$SILENT_MODE" = true ]; then
        exit 1
    fi

    # Use Platypus ALERT format
    echo "ALERT:Error|$1. See log for details."
    
    # Copy log to desktop for easy access
    cp "$LOG_FILE" ~/Desktop/ 2>/dev/null || true
    
    exit 1
}

log_and_notify(){
    log_message "$1"
    display_notification "$1"
    exit 1
}