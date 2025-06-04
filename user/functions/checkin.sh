# Function to check if files in the repository are open, excluding certain processes
check_open_files() {

    log_message "(BEGIN CHECK_OPEN_FILES)"

    open_files=$(lsof +D "$CHECKEDOUT_FOLDER/$selected_repo" | grep -v "^COMMAND" | grep -vE "(bash|lsof|awk|grep|mdworker_|osascript)")
    if [ -n "$open_files" ]; then
        log_message "Files are still open:"
        log_message "$open_files"
        return 0  # Files are open
    else
        log_message "No files are open."
        return 1  # No files are open
    fi
}

# Function to escape special characters for osascript
escape_for_applescript() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed "s/'/\\'/g"
}


moveToHiddenCheckinFolder(){
    log_message "moving repo to .checkedin folder..."
    mv "$CHECKEDOUT_FOLDER/$selected_repo" "$CHECKEDIN_FOLDER/$selected_repo" || handle_error "Couldn't move $selected_repo to the checkedin folder – make sure you've closed all projects."

    log_message "Setting repository $selected_repo to read-only"
    chmod -R u-w "$CHECKEDIN_FOLDER/$selected_repo" || handle_error "Failed to set repository $selected_repo to read-only"
    log_message "Repository $selected_repo is now read-only"

}


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

checkin() {

    log_message "(BEGIN CHECKIN)"
    log_message "(CHECKOUT parameters: $1)"

    # Create a lock file to prevent multiple simultaneous operations
    LOCK_FILE="$DATA_FOLDER/.checkin_lock"
    if [ -f "$LOCK_FILE" ]; then
        lock_pid=$(cat "$LOCK_FILE")
        if ps -p "$lock_pid" > /dev/null 2>&1; then
            log_message "Another checkin operation is in progress (PID: $lock_pid)"
            osascript -e "display dialog \"Another checkin operation is currently in progress. Please wait for it to complete.\" buttons {\"OK\"} default button \"OK\""
            exit 1
        else
            # Process is not running, remove stale lock
            rm -f "$LOCK_FILE"
        fi
    fi

    # Create lock file with current process ID
    echo $$ > "$LOCK_FILE"

    # Function to clean up lock file on exit
    cleanup() {
        rm -f "$LOCK_FILE"
    }
    trap cleanup EXIT

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from checkout script: $selected_repo"
        cd "$CHECKEDOUT_FOLDER/$selected_repo"
    else
        select_repo "Which repository do you want to check in?"
    fi

    # Check connectivity before proceeding
    if ! check_connectivity; then
        log_message "No connectivity to origin for $selected_repo"
        osascript -e "display dialog \"Unable to connect to the server. Please check your internet connection and try again.\" buttons {\"OK\"} default button \"OK\""
        return 1
    fi
    
    display_dialog_timed "Syncing Project" "Uploading your changes to $selected_repo to the server...." "Hide"

    # Check for open files before proceeding
    while check_open_files; do
        user_choice=$(osascript -e "display dialog \"There are files in this repository that are still open in other applications.  Please make sure everything is closed before checking in.\n\nYou can check the log to see which applications are using files in the repository.\" buttons {\"Check-in Anyway (This is a bad idea)\", \"I've Closed Them\"} default button \"I've Closed Them\"")

        if [[ "$user_choice" == "button returned:Check-in Anyway (This is a bad idea)" ]]; then
            log_message "User chose to proceed with check-in despite open files."
            break  # Proceed with check-in
        fi
    done

    # Read the branch name from the .CHECKEDOUT file
    user_branch=$(grep 'branch_name=' "$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT" | cut -d '=' -f 2)

    # Remove checkedout files
    rm -f "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT" # V1 CHECKEDOUT File (remove once everyone is up-to-date)
    rm -f "$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT" # V2 .CHECKEDOUT File

    # Debugging: Log the branch name
    log_message "Branch name read from .CHECKEDOUT file: $user_branch"

    # Handle empty branch name
    if [ -z "$user_branch" ]; then
        handle_error "Branch name is empty. Check the .CHECKEDOUT file."
    fi

    # Push the user's branch to the remote repository
    git push -u origin "$user_branch" >> "$LOG_FILE" 2>&1 || handle_error "Failed to push branch $user_branch"

    commitAndPush

    # Determine the default branch name
    default_branch=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)

    # Switch to the default branch
    git checkout "$default_branch" >> "$LOG_FILE" 2>&1 || handle_error "Failed to switch to $default_branch branch"

    # Merge the user's branch into the default branch
    git merge "$user_branch" >> "$LOG_FILE" 2>&1 || handle_error "Failed to merge branch $user_branch into $default_branch"

    # Push the changes to the default branch
    git push origin "$default_branch" >> "$LOG_FILE" 2>&1 || handle_error "Failed to push changes to $default_branch branch"

    # Delete the user's branch
    git branch -d "$user_branch" >> "$LOG_FILE" 2>&1 || handle_error "Failed to delete branch $user_branch"
    git push origin --delete "$user_branch" >> "$LOG_FILE" 2>&1 || log_message "Failed to delete remote branch $user_branch"

    moveToHiddenCheckinFolder

    hide_dialog

    display_notification "Uploaded changes to $selected_repo." "$selected_repo has been successfully checked in."

    log_message "(END CHECKOUT)"

}