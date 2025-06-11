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

    # Create operation lock
    if ! create_operation_lock "checkin"; then
        return $RC_ERROR
    fi

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
        if ! cd "$CHECKEDOUT_FOLDER/$selected_repo"; then
            log_message "Error: Failed to change to repository directory: $CHECKEDOUT_FOLDER/$selected_repo"
            return $RC_ERROR
        fi
    else
        select_repo "Which repository do you want to check in?"
    fi
    
    display_dialog_timed "Syncing Project" "Uploading your changes to $selected_repo to the server...." "Hide"

    # Get commit message, using the saved message as default
    commit_message=$(get_commit_message "" "Check-in Log" "Let your teammates know what changes you made:" "$selected_repo")
    if [ $? -eq $RC_CANCEL ]; then
        log_message "User canceled check-in"
        return $RC_CANCEL
    elif [ $? -ne $RC_SUCCESS ]; then
        log_message "Error: Failed to get commit message"
        return $RC_ERROR
    fi

    # Handle the repository operation
    if ! handle_repo_operation "$OP_CHECKIN" "$selected_repo" "$commit_message" "true"; then
        log_message "Error: Failed to handle repository operation"
        return $RC_ERROR
    fi

    hide_dialog
    display_notification "Uploaded changes to $selected_repo." "$selected_repo has been successfully checked in."
    log_message "(END CHECKIN)"
    return $RC_SUCCESS
}