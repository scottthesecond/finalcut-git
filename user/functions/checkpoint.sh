# Function to create a checkpoint for a repository
# Parameters:
#   $1: repo_name - Optional repository name to checkpoint
# Returns:
#   0: Success
#   1: Error
#   2: User canceled
checkpoint() {
    log_message "(BEGIN CHECKPOINT)"
    log_message "(CHECKPOINT parameters: $1)"

    # Create operation lock
    if ! create_operation_lock "checkpoint"; then
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
        select_repo "Which repository do you want to checkpoint?"
    fi
    
    display_dialog_timed "Syncing Project" "Uploading your changes to $selected_repo to the server...." "Hide"

    # Handle the repository operation
    if ! handle_repo_operation "$OP_CHECKPOINT" "$selected_repo" "" "false"; then
        log_message "Error: Failed to handle repository operation"
        return $RC_ERROR
    fi

    hide_dialog
    display_notification "Uploaded changes to $selected_repo." "A checkpoint for $selected_repo has been created successfully."
    log_message "(END CHECKPOINT)"
    return $RC_SUCCESS
}
