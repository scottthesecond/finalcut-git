# Function to check if any files in the repository have been accessed recently
check_recent_access() {
    local repo_path="$CHECKEDOUT_FOLDER/$selected_repo"
    local one_hour_ago=$(date -v-1H +%s)
    local has_recent_access=0

    # Find all files in the repository (excluding .git directory)
    find "$repo_path" -type f -not -path "*/\.*" -print0 | while IFS= read -r -d '' file; do
        # Get the last access time of the file
        access_time=$(stat -f "%a" "$file")
        
        # If any file has been accessed in the last hour, set flag and break
        if [ "$access_time" -gt "$one_hour_ago" ]; then
            has_recent_access=1
            break
        fi
    done

    return $has_recent_access
}

# Function: Checkpoint all checked out repositories
checkpoint_all() {

    log_message "(BEGIN CHECKPOINT_ALL)"

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
            
            # Change to the repository directory
            cd "$CHECKEDOUT_FOLDER/$selected_repo" || continue

            # Check connectivity before proceeding
            if ! check_connectivity; then
                log_message "No connectivity to origin for $selected_repo, skipping checkpoint"
                continue
            fi

            # Check if any files are open
            if check_open_files; then
                log_message "Files are open in $selected_repo, skipping checkpoint"
                continue
            fi

            # Check if files have been accessed recently
            if ! check_recent_access; then
                log_message "No recent file access in $selected_repo, performing automatic checkin"
                # Perform full checkin instead of checkpoint
                checkin "$selected_repo"
                # Skip to next repository since this one is now checked in
                continue
            fi

            # If we get here, we're doing a normal checkpoint
            log_message "Creating checkpoint for: $selected_repo"
            update_checkin_time
            commitAndPush
            display_notification "Uploaded changes to $selected_repo." "A checkpoint for $selected_repo has been created sucessfully."
        fi
    done

    log_message "(END CHECKPOINT_ALL)"
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