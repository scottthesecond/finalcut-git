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
            
            

            echo "Creating checkpoint for: $selected_repo"
            #log_message "Creating checkpoint for: $selected_repo"
            #create_checkpoint "$selected_repo"

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