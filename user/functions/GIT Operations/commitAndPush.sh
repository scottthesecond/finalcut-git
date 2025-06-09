commitAndPush() {
    log_message "(BEGIN COMMITANDPUSH)"

    # Get the current date and the user's name
    current_date=$(date +"%Y-%m-%d")

    
    user_name=$(whoami)

    # Get Commit Message
    commit_message_user=$(grep 'commit_message=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
    
    if [ -z "$commit_message_user" ]; then
        commit_message="Commit on $current_date by $user_name"
    else
        commit_message="$user_name: $commit_message_user"
    fi

    # Check for unstaged changes
    log_message "Checking for unstaged changes in $selected_repo"
    if git diff-index --quiet HEAD --; then
        log_message "No changes to commit in $selected_repo."
        return 0
    fi

    # Stage all changes
    log_message "Staging changes in $selected_repo"
    git add . >> "$LOG_FILE" 2>&1 || handle_error "Failed to stage changes in $selected_repo"

    # Commit with the message and push
    log_message "Committing changes in $selected_repo"
    git commit -m "$commit_message" >> "$LOG_FILE" 2>&1 || handle_error "Git commit failed in $selected_repo"

    log_message "Pushing changes for $selected_repo"
    git push >> "$LOG_FILE" 2>&1 || handle_error "Git push failed for $selected_repo"
    
    log_message "Changes have been successfully checked in and pushed for $selected_repo."

    log_message "(END COMMITANDPUSH)"

}