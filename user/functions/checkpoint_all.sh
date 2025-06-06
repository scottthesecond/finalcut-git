# Function to check if any files in the repository have been accessed recently
check_recent_access() {

    log_message "(BEGIN CHECK_RECENT_ACCESS)"

    local repo_path="$CHECKEDOUT_FOLDER/$selected_repo"
    local one_hour_ago=$(date -v-1H +%s)
    local has_recent_access=0
    local recent_access_time=0
    local temp_file=$(mktemp)

    # Find all files in the repository (excluding .git directory) and store their access times
    find "$repo_path" -type f -not -path "*/\.*" -exec stat -f "%a" {} \; > "$temp_file"

    # Read the access times and find the most recent
    while IFS= read -r access_time; do
        # If any file has been accessed in the last hour, set flag
        if [ "$access_time" -gt "$one_hour_ago" ]; then
            has_recent_access=1
            recent_access_time=$access_time
        fi
    done < "$temp_file"

    # Clean up temp file
    rm "$temp_file"

    # Get the most recent access time from all files
    most_recent_time=$(find "$repo_path" -type f -not -path "*/\.*" -exec stat -f "%a" {} \; | sort -nr | head -n1)

    # Convert most recent time to readable format
    readable_time=$(date -r "$most_recent_time" "+%Y-%m-%d %H:%M:%S")

    if [ $has_recent_access -eq 1 ]; then
        log_message "Repo has been accessed in the last hour – we shouldn't try to auto-checkin; let's checkpoint instead."
        log_message "Last Accessed: $readable_time"
    else
        log_message "File has not been accessed in the last hour."
        log_message "Most Recent Access: $readable_time"
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
