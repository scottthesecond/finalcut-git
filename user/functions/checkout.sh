# Function to set the checkout log message in .CHECKEDOUT file
# Parameters:
#   $1: commit_message - The message to store
set_log_message() {
    local commit_message="$1"
    echo "checked_out_by=$CURRENT_USER" > ".CHECKEDOUT"
    echo "commit_message=$commit_message" >> ".CHECKEDOUT"
}

# Function to cancel checkout and clean up
# Parameters:
#   $1: error_message - The error message to display
cancel_checkout() {
    local error_message="$1"
    handle_error "$error_message"
    log_message "Cancelling checkout. Running git reset."
    git reset --hard HEAD
    moveToHiddenCheckinFolder
    log_message "Exiting."
    exit $RC_ERROR
}

# Function to check initial repository status
# Parameters:
#   $1: repo_name - Name of the repository to check
# Returns:
#   0: Ready for checkout
#   1: Already checked out
#   2: Needs cloning
check_repo_status() {
    local repo_name="$1"
    local repo_path="$CHECKEDOUT_FOLDER/$repo_name"
    
    # Check if already checked out
    if [ -d "$repo_path" ]; then
        log_message "Selected repo already checked out: $repo_name"
        return 1  # Already checked out
    fi
    
    # Check if available in CHECKEDIN_FOLDER
    if [ ! -d "$CHECKEDIN_FOLDER/$repo_name" ]; then
        log_message "Repository $repo_name does not exist locally. Cloning..."
        return 2  # Needs cloning
    fi
    
    return 0  # Ready for initial checkout
}

# Function to prepare repository for checkout
# Parameters:
#   $1: repo_path - Path to the repository
# Returns:
#   0: Success
#   1: Error
prepare_repo_for_checkout() {
    local repo_path="$1"
    local status=$RC_SUCCESS
    
    log_message "(BEGIN PREPARE_REPO_FOR_CHECKOUT)"
    log_message "Preparing repository at path: $repo_path"
    
    # Make repository writable
    log_message "Making repository writable..."
    if ! chmod -R u+w "$repo_path"; then
        log_message "Error: Failed to make repository writable"
        return $RC_ERROR
    fi
    
    # Change to repository directory
    log_message "Changing to repository directory..."
    if ! cd "$repo_path"; then
        log_message "Error: Failed to change to repository directory"
        return $RC_ERROR
    fi
    
    # Handle any pending changes
    log_message "Checking for pending changes..."
    if git status | grep -q "Your branch is ahead of 'origin/master'"; then
        log_message "Local branch is ahead of origin, attempting to push first"
        push_output=$(git push 2>&1)
        push_status=$?
        if [ $push_status -ne 0 ]; then
            log_message "Error: Failed to push ahead commits"
            log_message "Push output: $push_output"
            handle_git_conflict "$repo_path"
            return $RC_ERROR
        fi
    fi
    
    # Pull latest changes
    log_message "Pulling latest changes..."
    pull_output=$(git pull 2>&1)
    pull_status=$?
    if [ $pull_status -ne 0 ]; then
        log_message "Error: Failed to pull latest changes"
        log_message "Pull output: $pull_output"
        handle_git_conflict "$repo_path"
        return $RC_ERROR
    fi
    
    # Verify repository is still available after pull
    log_message "Verifying repository status..."
    if [ -f "CHECKEDOUT" ] || [ -f ".CHECKEDOUT" ]; then
        local status=$(get_checkedout_status "$repo_path")
        if [ -n "$status" ]; then
            IFS='|' read -r checked_out_by commit_message last_commit <<< "$status"
            if [ "$checked_out_by" != "$CURRENT_USER" ]; then
                log_message "Repository is already checked out by $checked_out_by"
                log_message "Checkout reason: $commit_message"
                hide_dialog
                osascript -e "display dialog \"Repository is already checked out by $checked_out_by.\nReason: $commit_message\" buttons {\"OK\"} default button \"OK\""
                return $RC_ERROR
            fi
        fi
    fi
    
    log_message "Repository prepared successfully"
    log_message "(END PREPARE_REPO_FOR_CHECKOUT)"
    return $RC_SUCCESS
}

# Main checkout function
# Parameters:
#   $1: repo_name - Optional repository name to check out
checkout() {
    log_message "(BEGIN CHECKOUT)"
    log_message "(CHECKOUT parameters: $1)"

    # Create operation lock
    if ! create_operation_lock "checkout"; then
        exit $RC_ERROR
    fi

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
    else
        log_message "Repository not passed from command. Prompting user to select..."
        select_repo "Check out a recent repository, or a new one?" --allowNew --checkedIn
    fi

    display_dialog_timed "Syncing Project" "Syncing $selected_repo from the server...." "Hide"

    # Check initial repository status
    check_repo_status "$selected_repo"
    status=$?
    
    case $status in
        1)  # Already checked out
            open_fcp_or_directory
            return $RC_SUCCESS
            ;;
        2)  # Needs cloning
            git clone "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$selected_repo.git" "$CHECKEDIN_FOLDER/$selected_repo" >> "$LOG_FILE" 2>&1 || cancel_checkout "Git clone failed for $selected_repo"
            log_message "Repository cloned: $selected_repo"
            ;;
    esac

    # Prepare repository for checkout
    repo_path="$CHECKEDIN_FOLDER/$selected_repo"
    if ! prepare_repo_for_checkout "$repo_path"; then
        cancel_checkout "Failed to prepare repository for checkout"
    fi

    # Get the commit message
    log_message "Getting commit message."
    commit_message=$(get_commit_message "" "Checkout Log" "Let your teammates know why you have the library checked out:")
    commit_status=$?
    log_message "$commit_status"
    
    if [ $commit_status -eq $RC_CANCEL ]; then
        cancel_checkout "User canceled checkout"
    elif [ $commit_status -ne $RC_SUCCESS ]; then
        cancel_checkout "Failed to get commit message"
    fi

    # Set checked out status and commit
    set_checkedout_status "$CURRENT_USER" "$commit_message" "$repo_path"
    commitAndPush "Checked out by $CURRENT_USER: $commit_message"
    if [ $? -ne 0 ]; then
        cancel_checkout "Failed to commit and push checkout status"
    fi

    # Move to checkedout folder
    log_message "Moving repo to checkedout folder..."
    move_to_checkedout || cancel_checkout "Couldn't move $selected_repo to the checked out folder"

    hide_dialog
    create_settings_plist

    display_notification "Checked out $selected_repo." "The project is ready to work on." "When you're done, launch UNFlab and select 'checkin', then $selected_repo"

    open_fcp_or_directory
    return $RC_SUCCESS
}