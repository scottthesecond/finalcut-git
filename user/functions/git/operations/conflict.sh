# Function to handle git conflicts
handle_git_conflict() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUPS_FOLDER/${repo_name}_${timestamp}"
    
    # Create backups folder if it doesn't exist
    mkdir -p "$BACKUPS_FOLDER"
    
    # Show warning to user
    echo "ALERT:Project Sync Conflict|Your version of the project has changes that conflict with the server version. Don't worry - we'll automatically resolve this by creating a backup of your current version and downloading the latest version from the server. Your work is safe and will be preserved in the backup folder."
    
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
        handle_error "We couldn't create a backup of your current version. Please close any applications that might be using the project files and try again."
        return 1
    fi
    
    # Use the normal checkout procedure to get a fresh copy
    log_message "Getting fresh copy of $repo_name using normal checkout procedure..."

    # Call checkout directly without capturing output to avoid interfering with progress display
    checkout "$repo_name"
    checkout_status=$?
    
    if [ $checkout_status -ne 0 ]; then
        log_message "ERROR: Failed to checkout fresh copy"
        handle_error "We couldn't automatically resolve the project conflict. Please try checking out the project again manually, or contact support if the problem persists."
        return 1
    fi
    
    log_message "Successfully moved conflicting version to $backup_path and pulled fresh copy"
    # Show success message to user
    echo "ALERT:Conflict Resolved Successfully|Great! The project conflict has been automatically resolved. Your previous version has been safely backed up, and you now have the latest version from the server. The project is ready to use."
    # Don't return an error here since the checkout succeeded
    return 0
}
