# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    echo "$1"
    log_message "ERROR: $1"

    # Skip notification if in silent mode
    if [ "$SILENT_MODE" = true ]; then
        exit 1
    fi

    osascript -e "display dialog \"Error: $1. See log for details.\" buttons {\"Copy Log to Desktop\", \"OK\"} default button \"OK\"" -e "if button returned of result is \"Copy Log to Desktop\" then do shell script \"cp '$LOG_FILE' ~/Desktop/\""
    exit 1
}

log_and_notify(){
    log_message "$1"
    display_notification "$1"
    exit 1
}