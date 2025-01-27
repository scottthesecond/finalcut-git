#!/bin/bash

# Function to check git connection
check_git_connection() {
    git remote update > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        handle_error "Failed to connect to the remote repository. Please check your network connection and remote repository settings."
    else
        log_message "Git connection successful."
    fi
}

# Function to check if files in the repository are open, excluding certain processes
check_open_files() {
    open_files=$(lsof +D "$CHECKEDOUT_FOLDER/$selected_repo" | grep -v "^COMMAND" | grep -vE "(bash|lsof|awk|grep|mdworker_|osascript)")
    if [ -n "$open_files" ]; then
        log_message "Files are still open:"
        log_message "$open_files"
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
    if git push >> "$LOG_FILE" 2>&1; then
        log_message "Changes have been successfully checked in and pushed for $selected_repo."
        echo "enabled" > "$AUTO_CHECKPOINT_FLAG"
    else
        log_message "Git push failed for $selected_repo"
        echo "disabled" > "$AUTO_CHECKPOINT_FLAG"
        handle_error "Git push failed for $selected_repo"
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

    # Check git connection before proceeding
    check_git_connection


    # Check for open files before proceeding
    while check_open_files; do
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

