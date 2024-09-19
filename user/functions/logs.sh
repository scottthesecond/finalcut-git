# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    echo "$1"
    log_message "ERROR: $1"
    osascript -e "display dialog \"Error: $1.  See log for details.\" buttons {\"OK\"} default button \"OK\""
    exit 1
}