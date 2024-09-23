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

checkin() {

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from checkout script: $selected_repo"
        cd "$CHECKEDOUT_FOLDER/$selected_repo"
    else
        select_repo "Which repository do you want to check in?"
    fi

    # Check for open files before proceeding
    while check_open_files; do
        open_files=$(lsof +D "$CHECKEDOUT_FOLDER/$selected_repo" | awk '{print $1, $9}' | grep -v "^COMMAND")

        # Limit the size of the message passed to osascript
        open_files_short=$(echo "$open_files" | head -n 10)  # Show only the first 10 entries
        log_message "Warned user about open files in repository:"
        log_message "$open_files_short"

        # Escape the open files list for AppleScript
        # escaped_open_files=$(escape_for_applescript "$open_files_short")

        # Show dialog to user listing the open files
        #user_choice=$(osascript -e "display dialog \"The following files are open in other applications (showing up to 10):\n\n$escaped_open_files\n\nPlease close these files or choose to check in anyway.\" buttons {\"Check-in Anyway\", \"I've Closed Them\"} default button \"I've Closed Them\"")
        user_choice=$(osascript -e "display dialog \"There are files in this repository that are still open in other applications.  Please make sure everything is closed before checking in.\n\nYou can check the log to see which applications are using files in the repository.\" buttons {\"Check-in Anyway (This is a bad idea)\", \"I've Closed Them\"} default button \"I've Closed Them\"")

        if [[ "$user_choice" == "button returned:Check-in Anyway (This is a bad idea)" ]]; then
            log_message "User chose to proceed with check-in despite open files."
            break  # Proceed with check-in
        fi
    done

    display_dialog_timed "Syncing Project" "Uploading your changes to $selected_repo to the server...." "Hide"


    # Get the current date and the user's name
    current_date=$(date +"%Y-%m-%d")
    user_name=$(whoami)

    # Stage all changes, commit with the current date and username, and push
    log_message "Staging changes in $selected_repo"
    rm "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT" 
    git add . >> "$LOG_FILE" 2>&1 || handle_error "Failed to stage changes in $selected_repo"
    log_message "Committing changes in $selected_repo"
    git commit -m "Commit on $current_date by $user_name" >> "$LOG_FILE" 2>&1 || handle_error "Git commit failed in $selected_repo"
    log_message "Pushing changes for $selected_repo"
    git push >> "$LOG_FILE" 2>&1 || handle_error "Git push failed for $selected_repo"
    log_message "Changes have been successfully checked in and pushed for $selected_repo."
    echo "Changes have been checked in and pushed for $selected_repo."

    moveToHiddenCheckinFolder

    hide_dialog

    display_notification "Uploaded changes to $selected_repo." "$selected_repo has been sucessfully checked in."


#    osascript -e "display dialog \"Changes have been checked in and pushed for $selected_repo.\" buttons {\"OK\"} default button \"OK\""

    # Set the repository to read-only
    #echo "Repository $selected_repo is now read-only."
}