#!/bin/bash

checkin() {

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from checkout script: $selected_repo"
        cd "$REPO_FOLDER/$selected_repo" || handle_error "Failed to navigate to $selected_repo"
    else
        select_repo
    fi

    # Get the current date and the user's name
    current_date=$(date +"%Y-%m-%d")
    user_name=$(whoami)

    # Stage all changes, commit with the current date and username, and push
    log_message "Staging changes in $selected_repo"
    rm "$REPO_FOLDER/$selected_repo/CHECKEDOUT" 
    git add . >> "$LOG_FILE" 2>&1 || handle_error "Failed to stage changes in $selected_repo"
    log_message "Committing changes in $selected_repo"
    git commit -m "Commit on $current_date by $user_name" >> "$LOG_FILE" 2>&1 || handle_error "Git commit failed in $selected_repo"
    log_message "Pushing changes for $selected_repo"
    git push >> "$LOG_FILE" 2>&1 || handle_error "Git push failed for $selected_repo"

    log_message "Changes have been successfully checked in and pushed for $selected_repo."
    echo "Changes have been checked in and pushed for $selected_repo."

    # Set the repository to read-only
    log_message "Setting repository $selected_repo to read-only"
    chmod -R u-w "$REPO_FOLDER/$selected_repo" || handle_error "Failed to set repository $selected_repo to read-only"
    log_message "Repository $selected_repo is now read-only"
    echo "Repository $selected_repo is now read-only."
}

