set_log_message() {
    CURRENT_USER=$(whoami)

    echo "checked_out_by=$CURRENT_USER" > ".CHECKEDOUT"
    echo "commit_message=$commit_message" >> ".CHECKEDOUT"

}

cancel_checkout() {

    handle_error "$1"
    log_message "Cancelling checkout.  running git reset."
    git reset --hard HEAD

    moveToHiddenCheckinFolder

    log_message "Exiting."
    exit 1

}

move_to_checkedout(){
    mv "$CHECKEDIN_FOLDER/$selected_repo" "$CHECKEDOUT_FOLDER/$selected_repo"
}

checkout() {

    log_message "(BEGIN CHECKOUT)"
    log_message "(CHECKOUT parameters: $1)"

    # Create a lock file to prevent multiple simultaneous operations
    LOCK_FILE="$DATA_FOLDER/.checkout_lock"
    if [ -f "$LOCK_FILE" ]; then
        lock_pid=$(cat "$LOCK_FILE")
        if ps -p "$lock_pid" > /dev/null 2>&1; then
            log_message "Another checkout operation is in progress (PID: $lock_pid)"
            osascript -e "display dialog \"Another checkout operation is currently in progress. Please wait for it to complete.\" buttons {\"OK\"} default button \"OK\""
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
        log_message "Repository passed from command: $selected_repo"
    else
        log_message "Repository not passed from command.  Prompting user to select..."
        select_repo "Check out a recent repository, or a new one?" --allowNew --checkedIn
    fi

    display_dialog_timed "Syncing Project" "Syncing $selected_repo from the server...." "Hide"

    # Check if the repository exists locally in CHECKEDOUT_FOLDER
    if [ -d "$CHECKEDOUT_FOLDER/$selected_repo" ]; then
        log_message "Selected repo already checked out: $selected_repo"
        open_fcp_or_directory
        return
    fi

    # Check if the repository is available in the CHECKEDIN_FOLDER
    if [ ! -d "$CHECKEDIN_FOLDER/$selected_repo" ]; then
        log_message "Repository $selected_repo does not exist locally. Cloning..."
        
        # Clone it directly to CHECKEDOUT_FOLDER if not cached
        git clone "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$selected_repo.git" "$CHECKEDIN_FOLDER/$selected_repo" >> "$LOG_FILE" 2>&1 || handle_error "Git clone failed for $selected_repo"
        log_message "Repository cloned: $selected_repo"

        # Set the directory writable in CHECKEDIN_FOLDER and proceed with other actions
        chmod -R u+w "$CHECKEDIN_FOLDER/$selected_repo" || cancel_checkout "Failed to make repository $selected_repo writable"
        log_message "Repository $selected_repo is now writable."

        cd "$CHECKEDIN_FOLDER/$selected_repo"
    else
        # If cached, make it writable and perform git pull in CHECKEDIN_FOLDER
        log_message "Repository $selected_repo is cached, but not checked out."
        log_message "Making repository $selected_repo writable"
        
        chmod -R u+w "$CHECKEDIN_FOLDER/$selected_repo" || cancel_checkout "Failed to make repository $selected_repo writable"

        cd "$CHECKEDIN_FOLDER/$selected_repo"

        log_message "Running git pull in $selected_repo"
        git pull >> "$LOG_FILE" 2>&1 || cancel_checkout "Git pull failed for $selected_repo"
    fi

    # Check if the repository is already checked out
    if [ -f "CHECKEDOUT" ] || [ -f ".CHECKEDOUT" ]; then
        if [ -f "CHECKEDOUT" ]; then
            checked_out_by=$(cat "CHECKEDOUT") # Backwards compatibility with old version of unflab that did not use a hidden file
        elif [ -f ".CHECKEDOUT" ]; then
            checked_out_by=$(grep 'checked_out_by=' ".CHECKEDOUT" | cut -d '=' -f 2)
            commit_message=$(grep 'commit_message=' ".CHECKEDOUT" | cut -d '=' -f 2)
            branch_name=$(grep 'branch_name=' ".CHECKEDOUT" | cut -d '=' -f 2)
        fi

        if [ "$checked_out_by" != "$CURRENT_USER" ]; then
            log_message "Repository is already checked out by $checked_out_by on branch $branch_name"
            hide_dialog
            osascript -e "display dialog \"Repository is already checked out by $checked_out_by on branch $branch_name.\nReason: $commit_message\" buttons {\"OK\"} default button \"OK\""
            exit 1
        fi
    else
        # Create a new branch for the user with a timestamp
        timestamp=$(date +"%Y%m%d%H%M%S")
        # user_branch="checkout-$CURRENT_USER-$timestamp"

        # Get the commit message
        commit_message=$(osascript -e 'display dialog "Let your teammates know why you have the library checked out:" default answer "" with title "Checkout Log"' -e 'text returned of result')

        # Set log message with branch name
        set_log_message() {
            CURRENT_USER=$(whoami)
            echo "checked_out_by=$CURRENT_USER" > ".CHECKEDOUT"
            echo "commit_message=$commit_message" >> ".CHECKEDOUT"
            # echo "branch_name=$user_branch" >> ".CHECKEDOUT"
        }

        set_log_message

        git add . >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to add CHECKEDOUT file."
        git commit -m "Checked out by $CURRENT_USER: $commit_message" >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to commit CHECKEDOUT file."
        git push >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to push CHECKEDOUT file."
        log_message "Repository checked out by $CURRENT_USER"
    fi

    # git checkout -b "$user_branch" >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to create branch $user_branch"
    # git push -u origin "$user_branch" >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to push branch $user_branch"
    # log_message "Created and switched to branch $user_branch"

    # Move it to CHECKEDOUT_FOLDER after successful pull
    log_message "Moving repo to checkedout folder..."
    move_to_checkedout || cancel_checkout "Couldn't move $selected_repo to the checked out folder"

    hide_dialog

    create_settings_plist

    display_notification "Checked out $selected_repo." "The project is ready to work on." "When you're done, launch UNFlab and select 'checkin', then $selected_repo"

    open_fcp_or_directory
}