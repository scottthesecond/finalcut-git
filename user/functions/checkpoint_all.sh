
update_checkin_time() {

    # Format the current time as MM/DD HH:MM
    current_time=$(date "+%m/%d %H:%M")

    cd "$CHECKEDOUT_FOLDER/$selected_repo"
    CHECKEDOUT_FILE="$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT"

        # Update or append LAST_CHECKIN in the .CHECKEDOUT file
    if grep -q "^LAST_COMMIT=" "$CHECKEDOUT_FILE"; then
     sed -i '' "s|^LAST_COMMIT=.*|LAST_COMMIT=$current_time|" "$CHECKEDOUT_FILE"
    else
        echo "LAST_COMMIT=$current_time" >> "$CHECKEDOUT_FILE"
    fi

}

# Function: Checkpoint all checked out repositories
checkpoint_all() {
    log_message "(BEGIN CHECKPOINT_ALL)"
    
    # Get all checked out repositories
    folders=("$CHECKEDOUT_FOLDER"/*)
    log_message "Found ${#folders[@]} checked out folders."
    
    # Check if there are any repositories
    if [ ${#folders[@]} -eq 0 ]; then
        log_message "No repositories are currently checked out."
        return
    fi
    
    for folder in "${folders[@]}"; do
        if [ -d "$folder" ]; then
            selected_repo=$(basename "$folder")
            log_message "Processing repo: $selected_repo"
            
            # Change to the repository directory
            cd "$CHECKEDOUT_FOLDER/$selected_repo" || { log_message "Failed to cd into $CHECKEDOUT_FOLDER/$selected_repo"; continue; }

            # Check connectivity before proceeding
            if ! check_connectivity; then
                log_message "No connectivity to origin for $selected_repo, skipping checkpoint."
                continue
            fi

            # Check if any files are open and check recent access
            check_open_files
            open_files_result=$?
            check_recent_access
            recent_access_result=$?

            if [ $open_files_result -eq 1 ] && [ $recent_access_result -eq 0 ]; then
                log_message "No files open and no recent file access in $selected_repo, performing automatic checkin instead of checkpoint."
                # Perform full checkin instead of checkpoint
                checkin "$selected_repo"
                # Skip to next repository since this one is now checked in
                continue
            fi

            # If we get here, we're doing a normal checkpoint
            log_message "Creating checkpoint for: $selected_repo"
            update_checkin_time
            commitAndPush
            log_message "Checkpoint created for $selected_repo."
            display_notification "Uploaded changes to $selected_repo." "A checkpoint for $selected_repo has been created sucessfully."
        else
            log_message "Skipping $folder (not a directory)"
        fi
    done

    log_message "(END CHECKPOINT_ALL)"
}
