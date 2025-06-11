# Function to update the last checkin time in .CHECKEDOUT file
# Parameters:
#   $1: repo_path - Path to the repository
# Returns:
#   0: Success
#   1: Error
update_checkin_time() {
    # Validate required parameters
    if [ -z "$1" ]; then
        log_message "Error: Missing repository path in update_checkin_time"
        return $RC_ERROR
    fi

    local repo_path="$1"
    local checkedout_file="$repo_path/.CHECKEDOUT"
    
    # Validate repository path
    if [ ! -d "$repo_path" ]; then
        log_message "Error: Repository path does not exist: $repo_path"
        return $RC_ERROR
    fi
    
    # Format the current time as MM/DD HH:MM
    local current_time=$(date "+%m/%d %H:%M")
    
    # Update or append LAST_COMMIT in the .CHECKEDOUT file
    if grep -q "^LAST_COMMIT=" "$checkedout_file"; then
        if ! sed -i '' "s|^LAST_COMMIT=.*|LAST_COMMIT=$current_time|" "$checkedout_file"; then
            log_message "Error: Failed to update LAST_COMMIT in .CHECKEDOUT file"
            return $RC_ERROR
        fi
    else
        if ! echo "LAST_COMMIT=$current_time" >> "$checkedout_file"; then
            log_message "Error: Failed to append LAST_COMMIT to .CHECKEDOUT file"
            return $RC_ERROR
        fi
    fi
    
    log_message "Successfully updated checkin time for $repo_path"
    return $RC_SUCCESS
}

# Function to checkpoint all checked out repositories
# Returns:
#   0: Success
#   1: Error
checkpoint_all() {
    log_message "(BEGIN CHECKPOINT_ALL)"
    
    # Create operation lock
    if ! create_operation_lock "checkpoint_all"; then
        return $RC_ERROR
    fi
    
    # Get all checked out repositories
    folders=("$CHECKEDOUT_FOLDER"/*)
    log_message "Found ${#folders[@]} checked out folders."
    
    # Check if there are any repositories
    if [ ${#folders[@]} -eq 0 ]; then
        log_message "No repositories are currently checked out."
        return $RC_SUCCESS
    fi
    
    for folder in "${folders[@]}"; do
        if [ -d "$folder" ]; then
            selected_repo=$(basename "$folder")
            log_message "Processing repo: $selected_repo"
            
            # Change to the repository directory
            if ! cd "$CHECKEDOUT_FOLDER/$selected_repo"; then
                log_message "Error: Failed to change to repository directory: $CHECKEDOUT_FOLDER/$selected_repo"
                continue
            fi

            # Check if any files are open and check recent access
            check_open_files
            open_files_result=$?
            check_recent_access
            recent_access_result=$?

            if [ $open_files_result -eq 1 ] && [ $recent_access_result -eq 0 ]; then
                log_message "No files open and no recent file access in $selected_repo, performing automatic checkin instead of checkpoint."
                # Perform full checkin instead of checkpoint
                if ! checkin "$selected_repo"; then
                    log_message "Error: Failed to checkin $selected_repo"
                    continue
                fi
                # Skip to next repository since this one is now checked in
                continue
            fi

            # If we get here, we're doing a normal checkpoint
            log_message "Creating checkpoint for: $selected_repo"
            if ! checkpoint "$selected_repo"; then
                log_message "Error: Failed to checkpoint $selected_repo"
                continue
            fi
        else
            log_message "Skipping $folder (not a directory)"
        fi
    done

    log_message "(END CHECKPOINT_ALL)"
    return $RC_SUCCESS
}
