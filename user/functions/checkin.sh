#!/bin/bash

# Function to check if files in the repository are open, excluding certain processes
check_open_files() {
    open_files=$(lsof +D "$CHECKEDOUT_FOLDER/$selected_repo" | grep -v "^COMMAND" | grep -vE "(bash|lsof|awk|grep|mdworker_)")
    if [ -n "$open_files" ]; then
        echo "$open_files"
        return 0  # Files are open
    else
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

    # Get the current date and the user's name
    current_date=$(date +"%Y-%m-%d")
    user_name=$(whoami)

    #Get Commit Message
    commit_message_user=""
    commit_message_user=$(grep 'commit_message=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
    
    if [ -z "$commit_message_user" ]; then
        commit_message="Commit on $current_date by $user_name"
    else
        commit_message="$user_name: $commit_message"
    fi


    # Stage all changes, commit with the current date and username, and push
    log_message "Staging changes in $selected_repo"
    git add . >> "$LOG_FILE" 2>&1 || handle_error "Failed to stage changes in $selected_repo"
    log_message "Committing changes in $selected_repo"
    git commit -m "$commit_message" >> "$LOG_FILE" 2>&1 || handle_error "Git commit failed in $selected_repo"
    log_message "Pushing changes for $selected_repo"
    git push >> "$LOG_FILE" 2>&1 || handle_error "Git push failed for $selected_repo"
    log_message "Changes have been successfully checked in and pushed for $selected_repo."

}


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


checkin() {

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from checkout script: $selected_repo"
        cd "$CHECKEDOUT_FOLDER/$selected_repo"
    else
        select_repo "Which repository do you want to check in?"
    fi
    
    display_dialog_timed "Syncing Project" "Uploading your changes to $selected_repo to the server...." "Hide"

    # Check for open files before proceeding
    while check_open_files; do
        open_files=$(lsof +D "$CHECKEDOUT_FOLDER/$selected_repo" | awk '{print $1, $9}' | grep -v "^COMMAND")

        open_files_short=$(echo "$open_files" | head -n 10)  # Show only the first 10 entries
        log_message "Warned user about open files in repository:"
        log_message "$open_files_short"

        user_choice=$(osascript -e "display dialog \"There are files in this repository that are still open in other applications.  Please make sure everything is closed before checking in.\n\nYou can check the log to see which applications are using files in the repository.\" buttons {\"Check-in Anyway (This is a bad idea)\", \"I've Closed Them\"} default button \"I've Closed Them\"")

        if [[ "$user_choice" == "button returned:Check-in Anyway (This is a bad idea)" ]]; then
            log_message "User chose to proceed with check-in despite open files."
            break  # Proceed with check-in
        fi
    done


    # Remove checkedout files
    rm -f "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT" #V1 CHECKEDOUT File (remove once everyone is up-to-date)
    rm -f "$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT" #V2 .CHECKEDOUT File

    commitAndPush

    moveToHiddenCheckinFolder

    hide_dialog

    display_notification "Uploaded changes to $selected_repo." "$selected_repo has been sucessfully checked in."


#    osascript -e "display dialog \"Changes have been checked in and pushed for $selected_repo.\" buttons {\"OK\"} default button \"OK\""

    # Set the repository to read-only
    #echo "Repository $selected_repo is now read-only."
}

