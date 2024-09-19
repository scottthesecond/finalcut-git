
checkout() {
    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
    else
        select_repo --allowNew
    fi

    # Check if the repository exists locally
    if [ ! -d "$REPO_FOLDER/$selected_repo" ]; then
        log_message "Repository $selected_repo does not exist locally. Cloning..."
        git clone "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$selected_repo.git" "$REPO_FOLDER/$selected_repo" >> "$LOG_FILE" 2>&1 || handle_error "Git clone failed for $new_repo"
        log_message "Repository cloned: $selected_repo"
        # osascript -e "display dialog \"New repository cloned: $selected_repo\" buttons {\"OK\"} default button \"OK\""

    else
        log_message "Selected existing repository: $selected_repo"
    fi
    
    log_message "Making repository $selected_repo writable"
    chmod -R u+w "$REPO_FOLDER/$selected_repo" || handle_error "Failed to make repository $selected_repo writable"

    log_message "Repository $selected_repo is now writable"
    
    echo "Repository $selected_repo is now writable."
    cd "$REPO_FOLDER/$selected_repo"

    log_message "Running git pull in $selected_repo"
    git pull >> "$LOG_FILE" 2>&1 || handle_error "Git pull failed for $selected_repo"

    # Navigate to the selected repository
    cd "$REPO_FOLDER/$selected_repo" || handle_error "Failed to navigate to $selected_repo"

    # Get the current user
    CURRENT_USER=$(whoami)

    # Check if the repository is already checked out
    if [ -f "$REPO_FOLDER/$selected_repo/CHECKEDOUT" ]; then
        checked_out_by=$(cat "$REPO_FOLDER/$selected_repo/CHECKEDOUT")
        if [ "$checked_out_by" != "$CURRENT_USER" ]; then
            chmod -R u-w "$REPO_FOLDER/$selected_repo"
            log_message "Repository is already checked out by $checked_out_by"
            osascript -e "display dialog \"Repository is already checked out by $checked_out_by.\" buttons {\"OK\"} default button \"OK\""
            exit 1
        fi
    else
        # Create the CHECKEDOUT file with the current user
        echo "$CURRENT_USER" > "$REPO_FOLDER/$selected_repo/CHECKEDOUT"
        git add "$REPO_FOLDER/$selected_repo/CHECKEDOUT" >> "$LOG_FILE" 2>&1 || handle_error "Failed to add CHECKEDOUT file."
        git commit -m "Checked out by $CURRENT_USER" >> "$LOG_FILE" 2>&1 || handle_error "Failed to commit CHECKEDOUT file."
        git push >> "$LOG_FILE" 2>&1 || handle_error "Failed to push CHECKEDOUT file."
        log_message "Repository checked out by $CURRENT_USER"
    fi

    # Open the repository directory
    open "$REPO_FOLDER/$selected_repo"

    # Use AppleScript to display two buttons
    response=$(osascript -e "display dialog \"You are now checked out into $selected_repo.\n\nYou can either press leave this window open and press 'Check In Now' when you are done making changes, or you can hide this window and check the project in with UNFlab later.\" buttons {\"Check In Now\", \"Hide UNFLab\"} default button \"Check In Now\"")

    # Check if the user selected 'Check In'
    if [[ "$response" == "button returned:Check In Now" ]]; then
        checkin "$selected_repo"
    else
        osascript -e "display dialog \"When you're finished editing, launch UNFlab, choose 'Check In', and select $selected_repo.\" buttons {\"OK\"} default button \"OK\""
    fi

}