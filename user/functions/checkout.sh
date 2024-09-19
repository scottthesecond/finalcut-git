
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
        git clone "$REMOTE_SERVER/$selected_repo.git" "$REPO_FOLDER/$selected_repo" >> "$LOG_FILE" 2>&1 || handle_error "Git clone failed for $selected_repo"
        log_message "Repository cloned: $selected_repo"
        osascript -e "display dialog \"New repository cloned: $selected_repo\" buttons {\"OK\"} default button \"OK\""

    else
        log_message "Selected existing repository: $selected_repo"
    fi
    
    log_message "Making repository $selected_repo writable"
    chmod -R u+w "$REPO_FOLDER/$selected_repo" || handle_error "Failed to make repository $selected_repo writable"

    log_message "Repository $selected_repo is now writable"
    
    echo "Repository $selected_repo is now writable."
    cd "$REPO_FOLDER/$selected_repo" || handle_error "Failed to navigate to $selected_repo"

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

    # Use AppleScript to inform the user
    osascript -e "display dialog \"You are now checked out into $selected_repo.  Press OK when you are done making changes, and the changes will be checked in.\" buttons {\"OK\"} default button \"OK\""

    checkin "$selected_repo"

}

# checkout(){

#     # Function to display the menu and allow the user to select or enter a new repo
#     select_repo() {
#         echo "Select an existing repository or enter the name of a new one:"
#         echo "-----------------------------------------------------------"

#         # List all folders inside the repos directory
#         folders=("$REPO_DIR"/*)
#         if [ ${#folders[@]} -eq 0 ]; then
#             echo "No repositories found in $REPO_DIR"
#         else
#             for i in "${!folders[@]}"; do
#                 folder_name=$(basename "${folders[$i]}")
#                 echo "$((i+1))) $folder_name"
#             done
#         fi

#         # Prompt user for selection or new entry
#         echo "N) Enter the name of a new repository"
#         echo ""
#         read -p "Enter your choice [1-${#folders[@]} or N for new]: " choice

#         # Handle user input
#         if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#folders[@]}" ]; then
#             selected_repo=$(basename "${folders[$((choice-1))]}")
#             log_message "Selected existing repository: $selected_repo"
#             # Make the repository writable again
#             log_message "Making repository $selected_repo writable"
#             log_message "Repository $selected_repo is now writable"
#             echo "Repository $selected_repo is now writable."
#             cd "$REPO_DIR/$selected_repo" || handle_error "Failed to navigate to $selected_repo"
#             log_message "Running git pull in $selected_repo"
#             git pull >> "$LOG_FILE" 2>&1 || handle_error "Git pull failed for $selected_repo"
#         elif [[ "$choice" =~ ^[Nn]$ ]]; then
#             read -p "Enter the name of the new repository: " new_repo
#             log_message "Cloning new repository: $new_repo"
#             git clone "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$new_repo.git" "$REPO_DIR/$new_repo" >> "$LOG_FILE" 2>&1 || handle_error "Git clone failed for $new_repo"
#             log_message "New repository cloned: $new_repo"

#             # Navigate into the new repository directory
#             selected_repo="$new_repo"
#             cd "$REPO_DIR/$selected_repo" || handle_error "Failed to navigate to $selected_repo"
#         else
#             echo "Invalid option. Please try again."
#             select_repo
#         fi
        
#         # Function to get the current username
#         CURRENT_USER=$(whoami)
        
#         # Check if the CHECKEDOUT file exists
#         if [ ! -f "$REPO_DIR/$selected_repo/CHECKEDOUT" ]; then
#             # If CHECKEDOUT does not exist, create it
#             echo "$CURRENT_USER" > "$REPO_DIR/$selected_repo/CHECKEDOUT"
#             git add "$REPO_DIR/$selected_repo/CHECKEDOUT" >> "$LOG_FILE" 2>&1 || handle_error "failed to check out."
#             git commit -m "Checked out by $CURRENT_USER" >> "$LOG_FILE" 2>&1 || handle_error "failed to check out."
#             git push >> "$LOG_FILE" 2>&1 || handle_error "failed to check out."
#             open "$REPO_DIR/$new_repo"
#         else
#             checked_out_by=$(cat "$REPO_DIR/$selected_repo/CHECKEDOUT")
            
#             if [ "$checked_out_by" != "$CURRENT_USER" ]; then
#                 chmod -R u-w "$REPO_DIR/$selected_repo"
#                 log_message "Repository is already checked out by $checked_out_by"
#                 echo "Repository is already checked out by $checked_out_by."
#                 exit 1
#             fi
#         fi
#     }

#     # Run the function to display the selection menu
#     select_repo



#     # Inform the user and wait for them to press Enter
#     echo "You are now checked out into $selected_repo."



#     read -p "Press Enter when you are done making changes, and the changes will be checked in."



#     # Automatically call the checkin.sh script to commit and push changes
#     "$HOME/fcp-git/checkin.sh" "$selected_repo"


# }