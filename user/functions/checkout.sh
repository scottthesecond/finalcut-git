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
    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
    else
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

        # Set the directory writable in CHECKEDOUT_FOLDER and proceed with other actions
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
            checked_out_by=$(cat "CHECKEDOUT") #Backwards compatability with old version of unflab that did not use a hidden file
        elif [ -f  ".CHECKEDOUT" ]; then
            checked_out_by=$(grep 'checked_out_by=' ".CHECKEDOUT" | cut -d '=' -f 2)
            commit_message=$(grep 'commit_message=' ".CHECKEDOUT" | cut -d '=' -f 2)
        fi

        if [ "$checked_out_by" != "$CURRENT_USER" ]; then
            
            log_message "Repository is already checked out by $checked_out_by"
            hide_dialog
            osascript -e "display dialog \"Repository is already checked out by $checked_out_by.\nReason: $commit_message\" buttons {\"OK\"} default button \"OK\""
            exit 1
        fi

    else

        #Get the commit message
        commit_message=$(osascript -e 'display dialog "Let your teammates know why you have the library checked out:" default answer "" with title "Checkout Log"' -e 'text returned of result')

        set_log_message

        git add . >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to add CHECKEDOUT file."
        git commit -m "Checked out by $CURRENT_USER: $commit_message" >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to commit CHECKEDOUT file."
        git push >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to push CHECKEDOUT file."
        log_message "Repository checked out by $CURRENT_USER"
    fi
    
    # Move it to CHECKEDOUT_FOLDER after successful pull
    log_message "Moving repo to checkedout folder..."
    move_to_checkedout || cancel_checkout "Couldn't move $selected_repo to the checked out folder"

    hide_dialog

    create_settings_plist

    display_notification "Checked out $selected_repo." "The project is ready to work on." "When you're done, launch UNFlab and select 'checkin', then $selected_repo"

    open_fcp_or_directory

}