# Function to handle git conflicts
handle_git_conflict() {
    local repo_name="$1"
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
    
    # Move current version to backup
    log_message "Moving current version to backup at $backup_path..."
    if ! mv "$CHECKEDOUT_FOLDER/$repo_name" "$backup_path"; then
        log_message "ERROR: Failed to create backup at $backup_path"
        osascript -e "display dialog \"Failed to create backup. Please contact support.\" buttons {\"OK\"} default button \"OK\""
        return 1
    fi
    
    # Use the normal checkout procedure to get a fresh copy
    log_message "Getting fresh copy of $repo_name using normal checkout procedure..."
    if ! checkout "$repo_name"; then
        log_message "ERROR: Failed to checkout fresh copy. Restoring from backup..."
        mv "$backup_path" "$CHECKEDOUT_FOLDER/$repo_name"
        osascript -e "display dialog \"Failed to get fresh copy. Your original version has been restored.\" buttons {\"OK\"} default button \"OK\""
        return 1
    fi
    
    log_message "Successfully moved conflicting version to $backup_path and pulled fresh copy"
}
