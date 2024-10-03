
set_log_message() {

    CHECKEDOUT_FILE="$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT"
    CURRENT_USER=$(whoami)

    echo "checked_out_by=$CURRENT_USER" > "$CHECKEDOUT_FILE"
    echo "commit_message=$commit_message" >> "$CHECKEDOUT_FILE"

}

cancel_checkout() {

    handle_error "$1"
    log_message "Cancelling checkout.  running git reset."
    git reset --hard HEAD

    moveToHiddenCheckinFolder

    log_message "Exiting."
    exit 1

}

checkout() {
    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
    else
        select_repo "Check out a recent repository, or a new one?" --allowNew --checkedIn
    fi

    display_dialog_timed "Syncing Project" "Syncing $selected_repo from the server...." "Hide"

    # Check if the repository exists locally
    if [ ! -d "$CHECKEDOUT_FOLDER/$selected_repo" ]; then
        log_message "Repo $selected_repo is not already checked out, seeing if we have it in the checkedin cache..."
        
        if [ ! -d "$CHECKEDIN_FOLDER/$selected_repo" ]; then
            #it is not cached, clone it
            log_message "Repository $selected_repo does not exist locally. Cloning..."
            
            git clone "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$selected_repo.git" "$CHECKEDOUT_FOLDER/$selected_repo" >> "$LOG_FILE" 2>&1 || handle_error "Git clone failed for $new_repo"

            log_message "Repository cloned: $selected_repo"
        else
            # it is cached, copy it to the checked out folder
            log_message "Repository $selected_repo is cached, but not checked out."
            log_message "Making repository $selected_repo writable"
            chmod -R u+w "$CHECKEDIN_FOLDER/$selected_repo" || cancel_checkout "Failed to make repository $selected_repo writable"
            log_message "moving repo to checkedout folder..."
            mv "$CHECKEDIN_FOLDER/$selected_repo" "$CHECKEDOUT_FOLDER/$selected_repo" || cancel_checkout "Couldn't move $selected_repo to the checked out folder"
        fi

    else
        log_message "Selected repo already checked out: $selected_repo"
    fi
    
    chmod -R u+w "$CHECKEDOUT_FOLDER/$selected_repo" || cancel_checkout "Failed to make repository $selected_repo writable"
    echo "Repository $selected_repo is now writable."
    cd "$CHECKEDOUT_FOLDER/$selected_repo"

    log_message "Running git pull in $selected_repo"
    git pull >> "$LOG_FILE" 2>&1 || cancel_checkout "Git pull failed for $selected_repo"

    # Navigate to the selected repository
    cd "$CHECKEDOUT_FOLDER/$selected_repo"

    # Get the current user
    CURRENT_USER=$(whoami)

    # Check if the repository is already checked out
    if [ -f "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT" ]; then
        checked_out_by=$(cat "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT")
        if [ "$checked_out_by" != "$CURRENT_USER" ]; then
            
            log_message "Repository is already checked out by $checked_out_by"
            hide_dialog
            osascript -e "display dialog \"Repository is already checked out by $checked_out_by.\" buttons {\"OK\"} default button \"OK\""
            moveToHiddenCheckinFolder
            exit 1
        fi
    else
        # Create the CHECKEDOUT file with the current user
        echo "$CURRENT_USER" > "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT"

        git add "$CHECKEDOUT_FILE" >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to add CHECKEDOUT file."
        git commit -m "Checked out by $CURRENT_USER" >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to commit CHECKEDOUT file."
        git push >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to push CHECKEDOUT file."
        log_message "Repository checked out by $CURRENT_USER"
    fi
    
    hide_dialog

    # Open the repository directory
    open "$CHECKEDOUT_FOLDER/$selected_repo"

    display_notification "Checked out $selected_repo." "The project is ready to work on." "When you're done, launch UNFlab and select 'checkin', then $selected_repo"

    # Use AppleScript to display two buttons
    #response=$(osascript -e "display dialog \"You are now checked out into $selected_repo.\n\nYou can either press leave this window open and press 'Check In Now' when you are done making changes, or you can hide this window and check the project in with UNFlab later.\" buttons {\"Check In Now\", \"Hide UNFLab\"} default button \"Check In Now\"")

    # Check if the user selected 'Check In'
    #if [[ "$response" == "button returned:Check In Now" ]]; then
    #    checkin "$selected_repo"
    #else
    #    osascript -e "display dialog \"When you're finished editing, launch UNFlab, choose 'Check In', and select $selected_repo.\" buttons {\"OK\"} default button \"OK\""
    #fi

}