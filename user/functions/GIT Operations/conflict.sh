# Function to handle git conflicts
handle_git_conflict() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUPS_FOLDER/${repo_name}_${timestamp}"
    
    # Create backups folder if it doesn't exist
    mkdir -p "$BACKUPS_FOLDER"
    
    # Show warning to user
    osascript -e "display dialog \"Your version of the project came out of sync with the server. To protect everyone's work and time, when you click OK, we will close Final Cut, make a backup of your current version, then download the most recent version of the project from the server.\" buttons {\"OK\"} default button \"OK\""
    
    # Force quit Final Cut Pro
    log_message "Forcing Final Cut Pro to quit..."
    pkill -f "Final Cut Pro"
    sleep 2  # Give it a moment to quit
    
    # Verify source directory exists
    if [ ! -d "$repo_path" ]; then
        log_message "ERROR: Source directory $repo_path does not exist"
        handle_error "Could not find repository to backup"
        return 1
    fi
    
    # Check and fix permissions if needed
    log_message "Checking directory permissions..."
    if [ ! -w "$repo_path" ]; then
        log_message "Directory is not writable, attempting to fix permissions..."
        chmod -R u+w "$repo_path" 2>&1 | while read -r line; do
            log_message "chmod: $line"
        done
    fi
    
    # Move current version to backup
    log_message "Moving current version to backup at $backup_path..."
    mv_output=$(mv "$repo_path" "$backup_path" 2>&1)
    mv_status=$?
    
    if [ $mv_status -ne 0 ]; then
        log_message "ERROR: Failed to create backup at $backup_path"
        log_message "mv error output: $mv_output"
        handle_error "Failed to create backup: $mv_output"
        return 1
    fi
    
    # Use the normal checkout procedure to get a fresh copy
    log_message "Getting fresh copy of $repo_name using normal checkout procedure..."

    checkout_output=$(checkout "$repo_name" 2>&1)
    checkout_status=$?
    if [ $checkout_status -ne 0 ]; then
        log_message "ERROR: Failed to checkout fresh copy"
        log_message "checkout output: $checkout_output"
        return 1
    fi
    
    log_message "Successfully moved conflicting version to $backup_path and pulled fresh copy"
}
