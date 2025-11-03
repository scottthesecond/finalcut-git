# Function to escape special characters for osascript
escape_for_applescript() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed "s/'/\\'/g"
}

# Function to check in a repository
# Parameters:
#   $1: repo_name - Optional repository name to check in
# Returns:
#   0: Success
#   1: Error
#   2: User canceled
checkin() {
    log_message "(BEGIN CHECKIN)"
    log_message "(CHECKIN parameters: $1)"

    # Show initial progress
    show_progress 10
    show_details_on
    show_details "Starting checkin process..."

    # Create operation lock
    if ! create_operation_lock "checkin"; then
        return $RC_ERROR
    fi

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
        show_details "Repository: $selected_repo"
        if ! cd "$CHECKEDOUT_FOLDER/$selected_repo"; then
            log_message "Error: Failed to change to repository directory: $CHECKEDOUT_FOLDER/$selected_repo"
            show_details "Failed to change to repository directory"
            return $RC_ERROR
        fi
    else
        show_details "Selecting repository to check in..."
        select_repo "Which repository do you want to check in?"
    fi

    # Check and update remote URL if needed
    local repo_path="$CHECKEDOUT_FOLDER/$selected_repo"
    log_message "Checking remote URL for repository: $selected_repo"
    if ! check_remote_url_matches "$selected_repo" "$repo_path"; then
        log_message "Remote URL mismatch detected, updating..."
        show_details "Updating repository remote URL..."
        if ! update_remote_url "$selected_repo" "$repo_path"; then
            log_message "Warning: Failed to update remote URL, continuing anyway"
        fi
    fi

    show_progress 30
    show_details "Getting commit message..."

    # Get commit message, using the saved message as default
    commit_message=$(get_commit_message "" "Check-in Log" "Let your teammates know what changes you made:" "$selected_repo")
    commit_status=$?
    log_message "$commit_status"

    if [ $commit_status -eq $RC_CANCEL ]; then
        log_message "User canceled check-in"
        show_details "Checkin cancelled by user"
        return $RC_CANCEL
    elif [ $commit_status -ne $RC_SUCCESS ]; then
        log_message "Error: Failed to get commit message"
        show_details "Failed to get commit message"
        return $RC_ERROR
    fi

    show_progress 50
    show_details "Processing repository changes..."

    # Handle the repository operation
    if ! handle_repo_operation "$OP_CHECKIN" "$selected_repo" "$commit_message" "true"; then
        log_message "Error: Failed to handle repository operation"
        show_details "Failed to process repository changes"
        return $RC_ERROR
    fi

    show_progress 100
    show_details "Checkin complete!"

    # Clean exit for progress bar mode, hide dialog for other modes
    if [ "$progressbar" = true ]; then
        clean_exit 0
    else
        hide_dialog
        display_notification "Uploaded changes to $selected_repo." "$selected_repo has been successfully checked in."
    fi
    
    log_message "(END CHECKIN)"
    return $RC_SUCCESS
}