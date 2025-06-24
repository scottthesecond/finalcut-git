# Function to create an operation lock
# Parameters:
#   $1: operation - The operation to lock (e.g., "checkout", "checkin")
# Returns:
#   0: Success
#   1: Error
create_operation_lock() {
    # Validate required parameters
    if [ -z "$1" ]; then
        log_message "Error: Missing operation parameter in create_operation_lock"
        return $RC_ERROR
    fi

    local operation="$1"
    local lock_file="$DATA_FOLDER/.${operation}_lock"
    
    # Validate DATA_FOLDER exists
    if [ ! -d "$DATA_FOLDER" ]; then
        log_message "Error: DATA_FOLDER does not exist: $DATA_FOLDER"
        return $RC_ERROR
    fi
    
    # Check for existing lock
    if [ -f "$lock_file" ]; then
        local lock_pid=$(cat "$lock_file")
        if [ -z "$lock_pid" ]; then
            log_message "Error: Lock file exists but is empty: $lock_file"
            rm -f "$lock_file"
        elif [ "$lock_pid" = "$$" ]; then
            # This is our own lock, we can safely remove it
            log_message "Found our own lock file, removing it"
            rm -f "$lock_file"
        elif ps -p "$lock_pid" > /dev/null 2>&1; then
            log_message "Another $operation operation is in progress (PID: $lock_pid)"
            echo "ALERT:Operation in Progress|Another $operation operation is currently in progress. Please wait for it to complete."
            return $RC_ERROR
        else
            # Process is not running, remove stale lock
            log_message "Found stale lock file for $operation (PID: $lock_pid), removing"
            rm -f "$lock_file"
        fi
    fi

    # Create lock file with current process ID
    if ! echo $$ > "$lock_file"; then
        log_message "Error: Failed to create lock file: $lock_file"
        return $RC_ERROR
    fi
    
    # Function to clean up lock file on exit
    cleanup() {
        if [ -f "$lock_file" ]; then
            rm -f "$lock_file" || log_message "Warning: Failed to remove lock file: $lock_file"
        fi
    }
    trap cleanup EXIT
    
    log_message "Created lock file for $operation operation (PID: $$)"
    return $RC_SUCCESS
} 