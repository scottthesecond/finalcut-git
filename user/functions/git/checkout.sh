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
    log_message "Cancelling checkout: $error_message"
    show_details "Checkout cancelled: $error_message"
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
    
    # Check if already checked out
    if repo_exists "$repo_name" "$CHECKEDOUT_FOLDER"; then
        log_message "Selected repo already checked out: $repo_name"
        return 1  # Already checked out
    fi
    
    # Check if available in CHECKEDIN_FOLDER
    if ! repo_exists "$repo_name" "$CHECKEDIN_FOLDER"; then
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
    show_details "Making repository writable..."
    if ! chmod -R u+w "$repo_path"; then
        log_message "Error: Failed to make repository writable"
        show_details "Failed to make repository writable"
        return $RC_ERROR
    fi
    
    # Change to repository directory
    log_message "Changing to repository directory..."
    show_details "Changing to repository directory..."
    if ! cd "$repo_path"; then
        log_message "Error: Failed to change to repository directory"
        show_details "Failed to change to repository directory"
        return $RC_ERROR
    fi
    
    # Handle any pending changes
    log_message "Checking for pending changes..."
    show_details "Checking for pending changes..."
    if git status | grep -q "Your branch is ahead of 'origin/master'"; then
        log_message "Local branch is ahead of origin, attempting to push first"
        show_details "Local branch is ahead, pushing changes first..."
        push_output=$(git push 2>&1)
        push_status=$?
        if [ $push_status -ne 0 ]; then
            log_message "Error: Failed to push ahead commits"
            log_message "Push output: $push_output"
            show_details "Failed to push ahead commits: $push_output"
            show_git_output "$push_output" "push"
            handle_git_conflict "$repo_path"
            conflict_status=$?
            if [ $conflict_status -eq 0 ]; then
                # Conflict was successfully resolved, the checkout should continue
                log_message "Conflict resolved successfully, continuing with checkout"
                return $RC_SUCCESS
            else
                # Conflict resolution failed
                return $RC_ERROR
            fi
        else
            show_details "Ahead commits pushed successfully"
            show_git_output "$push_output" "push"
        fi
    fi
    
    # Pull latest changes
    log_message "Pulling latest changes..."
    show_details "Pulling latest changes from server..."
    show_details "This may take a moment depending on your connection..."
    show_indeterminate_progress
    
    # Use git fetch first to get updates, then merge
    show_details "Fetching latest changes..."
    fetch_output=$(git fetch origin 2>&1)
    fetch_status=$?
    if [ $fetch_status -ne 0 ]; then
        log_message "Error: Failed to fetch latest changes"
        log_message "Fetch output: $fetch_output"
        show_details "Failed to fetch latest changes: $fetch_output"
        show_git_output "$fetch_output" "fetch"
        handle_git_conflict "$repo_path"
        conflict_status=$?
        if [ $conflict_status -eq 0 ]; then
            # Conflict was successfully resolved, the checkout should continue
            log_message "Conflict resolved successfully, continuing with checkout"
            return $RC_SUCCESS
        else
            # Conflict resolution failed
            return $RC_ERROR
        fi
    else
        show_details "Fetch completed successfully"
        show_git_output "$fetch_output" "fetch"
    fi
    
    # Now merge the changes
    show_details "Merging changes..."
    merge_output=$(git merge origin/master 2>&1)
    merge_status=$?
    if [ $merge_status -ne 0 ]; then
        log_message "Error: Failed to merge latest changes"
        log_message "Merge output: $merge_output"
        show_details "Failed to merge latest changes: $merge_output"
        show_git_output "$merge_output" "merge"
        handle_git_conflict "$repo_path"
        conflict_status=$?
        if [ $conflict_status -eq 0 ]; then
            # Conflict was successfully resolved, the checkout should continue
            log_message "Conflict resolved successfully, continuing with checkout"
            return $RC_SUCCESS
        else
            # Conflict resolution failed
            return $RC_ERROR
        fi
    else
        show_details "Latest changes pulled successfully"
        show_git_output "$merge_output" "merge"
    fi
    
    # Verify repository is still available after pull
    log_message "Verifying repository status..."
    show_details "Verifying repository status..."
    show_progress 60
    if [ -f "CHECKEDOUT" ] || [ -f ".CHECKEDOUT" ]; then
        local status=$(get_checkedout_status "$repo_path")
        if [ -n "$status" ]; then
            IFS='|' read -r checked_out_by commit_message last_commit <<< "$status"
            if [ "$checked_out_by" != "$CURRENT_USER" ]; then
                log_message "Repository is already checked out by $checked_out_by"
                log_message "Checkout reason: $commit_message"
                show_details "Repository already checked out by $checked_out_by"
                hide_dialog
                echo "ALERT:Repository Already Checked Out|Repository is already checked out by $checked_out_by. Reason: $commit_message"
                return $RC_ERROR
            fi
        fi
    fi
    
    log_message "Repository prepared successfully"
    show_details "Repository prepared successfully"
    log_message "(END PREPARE_REPO_FOR_CHECKOUT)"
    return $RC_SUCCESS
}

# Main checkout function
# Parameters:
#   $1: repo_name - Optional repository name to check out
checkout() {
    log_message "(BEGIN CHECKOUT)"
    log_message "(CHECKOUT parameters: $1)"

    # Show initial progress
    show_progress 10
    show_details_off
    show_details "Starting checkout process..."

    # Create operation lock
    if ! create_operation_lock "checkout"; then
        show_details_on
        exit $RC_ERROR
    fi

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
        show_details "Repository: $selected_repo"
    else
        log_message "Repository not passed from command. Prompting user to select..."
        show_details "Selecting repository..."
        select_repo "Check out a recent repository, or a new one?" --allowNew --checkedIn
    fi

    show_progress 20
    show_details "Checking repository status..."

    # Check initial repository status
    check_repo_status "$selected_repo"
    status=$?
    
    case $status in
        1)  # Already checked out
            show_progress 100
            show_details "Repository already checked out, opening..."
            open_fcp_or_directory
            return $RC_SUCCESS
            ;;
        2)  # Needs cloning
            show_progress 30
            show_details "Repository not found locally, cloning from server..."
            clone_output=$(git clone "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$selected_repo.git" "$CHECKEDIN_FOLDER/$selected_repo" 2>&1)
            clone_status=$?
            if [ $clone_status -ne 0 ]; then
                show_details_on
                show_details "Git clone failed: $clone_output"
                show_git_output "$clone_output" "clone"
                cancel_checkout "Git clone failed for $selected_repo"
            fi
            log_message "Repository cloned: $selected_repo"
            show_details "Repository cloned successfully"
            show_git_output "$clone_output" "clone"
            ;;
    esac

    show_progress 50
    show_details "Preparing repository for checkout..."

    # Prepare repository for checkout
    repo_path="$CHECKEDIN_FOLDER/$selected_repo"
    if ! prepare_repo_for_checkout "$repo_path"; then
        show_details_on
        cancel_checkout "Failed to prepare repository for checkout"
    fi

    show_progress 70
    show_details "Waiting for commit message..."

    # Get the commit message
    log_message "Getting commit message."
    commit_message=$(get_commit_message "" "Checkout Log" "Let your teammates know why you have the library checked out:")
    commit_status=$?
    log_message "$commit_status"
    
    if [ $commit_status -eq $RC_CANCEL ]; then
        show_details_on
        cancel_checkout "User canceled checkout"
    elif [ $commit_status -ne $RC_SUCCESS ]; then
        show_details_on
        cancel_checkout "Failed to get commit message"
    fi

    show_progress 80
    show_details "Setting checkout status and locking project..."

    # Set checked out status and commit
    set_checkedout_status "$CURRENT_USER" "$commit_message" "$repo_path"
    commitAndPush "Checked out by $CURRENT_USER: $commit_message"
    if [ $? -ne 0 ]; then
        show_details_on
        cancel_checkout "Failed to commit and push checkout status"
    fi

    show_progress 90
    show_details "Moving repository to checked out folder..."

    # Move to checkedout folder
    log_message "Moving repo to checkedout folder..."
    move_to_checkedout || cancel_checkout "Couldn't move $selected_repo to the checked out folder"

    show_progress 100
    show_details "Checkout complete! Opening project..."

    # Clean exit for progress bar mode, hide dialog for other modes
    if [ "$progressbar" = true ]; then
        clean_exit 0
    else
        hide_dialog
        display_notification "Checked out $selected_repo." "The project is ready to work on." "When you're done, launch UNFlab and select 'checkin', then $selected_repo"
    fi

    create_settings_plist

    open_fcp_or_directory
    return $RC_SUCCESS
}