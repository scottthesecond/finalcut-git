#!/bin/bash

# Offload queue management functions
# This file handles queueing of offload operations to prevent concurrent offloads

# Function to create an offload queue entry
# Parameters:
#   $1: input_path - The source path to offload
#   $2: source_name - The source name (card name)
#   $3: timestamp - When the queue entry was created
# Returns:
#   0: Success
#   1: Error
create_offload_queue_entry() {
    # Validate required parameters
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        log_message "Error: Missing required parameters in create_offload_queue_entry"
        return $RC_ERROR
    fi

    local input_path="$1"
    local source_name="$2"
    local timestamp="$3"
    local queue_file="$DATA_FOLDER/.offload_queue"
    
    # Validate DATA_FOLDER exists
    if [ ! -d "$DATA_FOLDER" ]; then
        log_message "Error: DATA_FOLDER does not exist: $DATA_FOLDER"
        return $RC_ERROR
    fi
    
    # Create queue entry: input_path|source_name|timestamp|status
    local queue_entry="$input_path|$source_name|$timestamp|queued"
    
    # Append to queue file
    if ! echo "$queue_entry" >> "$queue_file"; then
        log_message "Error: Failed to append to queue file: $queue_file"
        return $RC_ERROR
    fi
    
    log_message "Added offload to queue: $input_path ($source_name)"
    return $RC_SUCCESS
}

# Function to check if an offload is already in progress
# Returns:
#   0: No offload in progress
#   1: Offload in progress
check_offload_in_progress() {
    local lock_file="$DATA_FOLDER/.offload_lock"
    
    # Check for existing lock
    if [ -f "$lock_file" ]; then
        local lock_pid=$(cat "$lock_file")
        if [ -z "$lock_pid" ]; then
            log_message "Error: Lock file exists but is empty: $lock_file"
            rm -f "$lock_file"
            return 0  # No offload in progress
        elif [ "$lock_pid" = "$$" ]; then
            # This is our own lock, we can safely remove it
            log_message "Found our own offload lock file, removing it"
            rm -f "$lock_file"
            return 0  # No offload in progress
        elif ps -p "$lock_pid" > /dev/null 2>&1; then
            log_message "Another offload operation is in progress (PID: $lock_pid)"
            return 1  # Offload in progress
        else
            # Process is not running, remove stale lock
            log_message "Found stale offload lock file (PID: $lock_pid), removing"
            rm -f "$lock_file"
            return 0  # No offload in progress
        fi
    fi
    
    return 0  # No offload in progress
}

# Function to create an offload lock
# Returns:
#   0: Success
#   1: Error
create_offload_lock() {
    local lock_file="$DATA_FOLDER/.offload_lock"
    
    # Check if offload is already in progress
    if check_offload_in_progress; then
        # No offload in progress, we can proceed
        :
    else
        # Offload is in progress, we should queue this one
        return 1
    fi
    
    # Create lock file with current process ID
    if ! echo $$ > "$lock_file"; then
        log_message "Error: Failed to create offload lock file: $lock_file"
        return $RC_ERROR
    fi
    
    # Function to clean up lock file on exit
    cleanup() {
        if [ -f "$lock_file" ]; then
            rm -f "$lock_file" || log_message "Warning: Failed to remove offload lock file: $lock_file"
        fi
    }
    trap cleanup EXIT
    
    log_message "Created offload lock file (PID: $$)"
    return $RC_SUCCESS
}

# Function to get the next queued offload
# Returns:
#   Success: "input_path|source_name|timestamp|status"
#   Error: Empty string
get_next_queued_offload() {
    local queue_file="$DATA_FOLDER/.offload_queue"
    
    if [ ! -f "$queue_file" ]; then
        return 1  # No queue file
    fi
    
    # Get the first queued entry
    local first_entry=$(head -n 1 "$queue_file")
    if [ -z "$first_entry" ]; then
        return 1  # No entries in queue
    fi
    
    echo "$first_entry"
    return 0
}

# Function to remove the first entry from the queue
# Returns:
#   0: Success
#   1: Error
remove_first_queue_entry() {
    local queue_file="$DATA_FOLDER/.offload_queue"
    
    if [ ! -f "$queue_file" ]; then
        return 1  # No queue file
    fi
    
    # Create temporary file without first line
    local temp_file="${queue_file}.tmp"
    if ! tail -n +2 "$queue_file" > "$temp_file"; then
        log_message "Error: Failed to create temporary queue file"
        return $RC_ERROR
    fi
    
    # Replace original file with temporary file
    if ! mv "$temp_file" "$queue_file"; then
        log_message "Error: Failed to update queue file"
        return $RC_ERROR
    fi
    
    log_message "Removed first entry from offload queue"
    return $RC_SUCCESS
}

# Function to process the offload queue
# This function should be called after each offload completes
process_offload_queue() {
    local queue_file="$DATA_FOLDER/.offload_queue"
    
    log_message "Processing offload queue..."
    
    # Check if there are any queued offloads
    if [ ! -f "$queue_file" ]; then
        log_message "No offload queue file found"
        return $RC_SUCCESS
    fi
    
    # Check if queue is empty
    if [ ! -s "$queue_file" ]; then
        log_message "Offload queue is empty"
        rm -f "$queue_file"
        return $RC_SUCCESS
    fi
    
    # Get the next queued offload
    local next_offload=$(get_next_queued_offload)
    if [ -z "$next_offload" ]; then
        log_message "No queued offloads found"
        return $RC_SUCCESS
    fi
    
    # Parse the queue entry
    IFS='|' read -r input_path source_name timestamp status <<< "$next_offload"
    
    log_message "Processing queued offload: $input_path ($source_name)"
    
    # Remove the entry from the queue
    if ! remove_first_queue_entry; then
        log_message "Error: Failed to remove queue entry"
        return $RC_ERROR
    fi
    
    # Check if the input path still exists
    if [ ! -d "$input_path" ]; then
        log_message "Warning: Queued offload source no longer exists: $input_path"
        # Continue processing queue
        process_offload_queue
        return $RC_SUCCESS
    fi
    
    # Launch the offload in a new progress window
    log_message "Launching queued offload: $input_path ($source_name)"
    launch_progress_app "offload" "$input_path" "$source_name"
    
    return $RC_SUCCESS
}

# Function to add offload to queue and show notification
# Parameters:
#   $1: input_path - The source path to offload
#   $2: source_name - The source name (card name)
# Returns:
#   0: Success
#   1: Error
queue_offload() {
    local input_path="$1"
    local source_name="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Add to queue
    if ! create_offload_queue_entry "$input_path" "$source_name" "$timestamp"; then
        return $RC_ERROR
    fi
    
    # Show notification to user
    display_notification "Offload Queued" "Your offload from $source_name has been added to the queue and will start automatically when the current offload completes."
    
    log_message "Offload queued successfully: $input_path ($source_name)"
    return $RC_SUCCESS
}

# Function to check queue status
# Returns:
#   Success: Number of queued offloads
#   Error: 0
get_queue_status() {
    local queue_file="$DATA_FOLDER/.offload_queue"
    
    if [ ! -f "$queue_file" ]; then
        echo "0"
        return 0
    fi
    
    local queue_count=$(wc -l < "$queue_file" 2>/dev/null || echo "0")
    echo "$queue_count"
    return 0
}

# Function to clear the offload queue
# Returns:
#   0: Success
#   1: Error
clear_offload_queue() {
    local queue_file="$DATA_FOLDER/.offload_queue"
    
    if [ -f "$queue_file" ]; then
        if rm -f "$queue_file"; then
            log_message "Cleared offload queue"
            return $RC_SUCCESS
        else
            log_message "Error: Failed to clear offload queue"
            return $RC_ERROR
        fi
    fi
    
    log_message "No offload queue to clear"
    return $RC_SUCCESS
}

# Function to show queue contents (for debugging)
# Returns:
#   Success: Queue contents as formatted string
#   Error: Empty string
show_queue_contents() {
    local queue_file="$DATA_FOLDER/.offload_queue"
    
    if [ ! -f "$queue_file" ]; then
        echo "No queue file found"
        return 0
    fi
    
    if [ ! -s "$queue_file" ]; then
        echo "Queue is empty"
        return 0
    fi
    
    local queue_contents=""
    local line_number=1
    
    while IFS='|' read -r input_path source_name timestamp status; do
        queue_contents="${queue_contents}${line_number}. $source_name ($input_path) - $timestamp\n"
        ((line_number++))
    done < "$queue_file"
    
    echo -e "$queue_contents"
    return 0
} 