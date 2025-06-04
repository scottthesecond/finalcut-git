# Function to check if any files in the repository have been accessed recently
check_recent_access() {
    local repo_path="$CHECKEDOUT_FOLDER/$selected_repo"
    local one_hour_ago=$(date -v-1H +%s)
    local has_recent_access=0
    local recent_access_time=0

    # Find all files in the repository (excluding .git directory)
    find "$repo_path" -type f -not -path "*/\.*" -print0 | while IFS= read -r -d '' file; do
        # Get the last access time of the file
        access_time=$(stat -f "%a" "$file")

        # If any file has been accessed in the last hour, set flag and break
        if [ "$access_time" -gt "$one_hour_ago" ]; then
            has_recent_access=1
            recent_access_time=$access_time
            break
        fi
    done

    if [ $has_recent_access -eq 1 ]; then
        log_message "Repo has been accessed in the last hour – we shouldn't try to auto-checkin; let's checkpoint instead."
        log_message "Last Accessed: $recent_access_time"
    fi

    return $has_recent_access
}

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

    echo "AUTOSAVE SCRIPT RAN at $(date)" >> ~/fcp-git/logs/autosave-debug.log
    
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

            # Check if any files are open
            if ! check_open_files && ! check_recent_access; then
                log_message "No files open and no recent file access in $selected_repo, performing automatic checkin."
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
