checkpoint() {

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        cd "$CHECKEDOUT_FOLDER/$selected_repo"
    else
        select_repo "Which repository do you want to Checkpoint?"
    fi

    CHECKEDOUT_FILE="$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT"

    commit_message_user=""
    commit_message_user=$(grep 'commit_message=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)

    log_message "Current commit message: $commit_message_user"

    update_checkin_time

    result=$(osascript -e "display dialog \"What did you change so far?\nI'll sync the project to the server (It'll stay checked out) with the log message below.\n\nIf you'll be working on something different going forward and would like to change your log message for autosaves after this, use Checkpoint w/ New Log Message.\" default answer \"$commit_message_user\" with title \"New Checkpoint\" buttons {\"Cancel\", \"Checkpoint\", \"Checkpoint and Change Message\"} default button \"Checkpoint\"")
    
    log_message "Dialog Result: $result"
    
        # Parse button clicked and commit message using sed
        button_clicked=$(echo "$result" | sed -n 's/.*button returned:\(.*\), text returned.*/\1/p' | tr -d ', ')
        commit_message=$(echo "$result" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')

        # Log the parsed values for debugging
        log_message "Button clicked: $button_clicked"
        log_message "Commit message: $commit_message"

    set_log_message
    
    if [ "$button_clicked" = "Checkpoint" ]; then

        
         display_dialog_timed "Creating Checkpoint..." "Uploading your changes to $selected_repo to the server...." "Hide"

         commitAndPush
         display_notification "Uploaded changes to $selected_repo." "A checkpoint for $selected_repo has been created sucessfully."
         hide_dialog
        # create_checkpoint

        # Code to execute when confirmed
        log_message "Confirmed with message: $commit_message"
        # Add your logic here for when the user confirms
    elif [ "$button_clicked" = "CheckpointandChangeMessage" ]; then
        
        nextResult=$(osascript -e "display dialog \"What are you working on now?\n\nI'll use this for autosaves going forward\" default answer \"$commit_message\" with title \"Checkpoint Message\" buttons {\"OK\"} default button \"OK\"")

        display_dialog_timed "Creating Checkpoint..." "Uploading your changes to $selected_repo to the server...." "Hide"
        commitAndPush
        
        commit_message=$(echo "$nextResult" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')
        set_log_message

        display_notification "Uploaded changes to $selected_repo." "A checkpoint for $selected_repo has been created sucessfully."
        hide_dialog

        log_message "Checkpoint Created and message changed to: $commit_message"

    else
        # Code to execute when canceled
        log_message "User canceled"
        # Add your logic here for when the user cancels
    fi




}


# Function: Checkpoint all checked out repositories
checkpoint_all() {

    # Check if auto checkpoint is enabled
    if [ -f "$AUTO_CHECKPOINT_FLAG" ] && [ "$(cat "$AUTO_CHECKPOINT_FLAG")" = "disabled" ]; then
        log_message "Auto checkpoint is disabled due to a previous check-in failure."
        echo "Auto checkpoint is disabled due to a previous check-in failure."
        return
    fi

    # Get all checked out repositories
    folders=("$CHECKEDOUT_FOLDER"/*)
    
    # Check if there are any repositories
    if [ ${#folders[@]} -eq 0 ]; then
        echo "No repositories are currently checked out."
        return
    fi
    
    for folder in "${folders[@]}"; do
        if [ -d "$folder" ]; then
            selected_repo=$(basename "$folder")
            
            

            echo "Creating checkpoint for: $selected_repo"
            #log_message "Creating checkpoint for: $selected_repo"
            #create_checkpoint "$selected_repo"

            update_checkin_time
            commitAndPush
            display_notification "Uploaded changes to $selected_repo." "A checkpoint for $selected_repo has been created sucessfully."

        fi
    done
}

update_checkin_time() {

    # Format the current time as MM/DD HH:MM
    current_time=$(date "+%m/%d %H:%M")

    cd "$CHECKEDOUT_FOLDER/$selected_repo"
    CHECKEDOUT_FILE="$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT"

    # Update or append LAST_CHECKIN in the .CHECKEDOUT file
    if grep -q "^LAST_CHECKIN=" "$CHECKEDOUT_FILE"; then
        sed -i '' "s|^LAST_CHECKIN=.*|LAST_CHECKIN=$current_time|" "$CHECKEDOUT_FILE"
    else
        echo "LAST_CHECKIN=$current_time" >> "$CHECKEDOUT_FILE"
    fi

    # Update or append LAST_COMMIT in the .CHECKEDOUT file
    if grep -q "^LAST_COMMIT=" "$CHECKEDOUT_FILE"; then
        sed -i '' "s|^LAST_COMMIT=.*|LAST_COMMIT=$current_time|" "$CHECKEDOUT_FILE"
    else
        echo "LAST_COMMIT=$current_time" >> "$CHECKEDOUT_FILE"
    fi

}