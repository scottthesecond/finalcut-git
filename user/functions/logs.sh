# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    local error_message="$1"
    local show_dialog="$2"

    echo "$error_message"
    log_message "ERROR: $error_message"

    if [ "$show_dialog" = true ]; then
        osascript -e "display dialog \"Error: $error_message. See log for details.\" buttons {\"OK\"} default button \"OK\""
    else
        display_notification "Error" "$error_message" "See log for details."
    fi

    exit 1
}