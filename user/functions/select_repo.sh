# Function to select a repo using AppleScript
select_repo() {

    log_message " //// BEGIN SELECT_REPO \\\\"


    local enable_new="false"
    local folders=("$CHECKEDOUT_FOLDER"/*)
    local prompt_text="Select an existing repository:" # Default prompt

    # Check for passed arguments
    for arg in "$@"; do
        if [ "$arg" == "--allowNew" ]; then
            enable_new="true"
        elif [ "$arg" == "--checkedIn" ]; then
            folders=("$CHECKEDIN_FOLDER"/*)
        else
            prompt_text="$arg"  # Set the argument as the custom prompt
        fi
    done
   
    # Check if there are any repositories
    if [ ${#folders[@]} -eq 0 ]; then
        osascript -e 'display dialog "No repositories found in the repos folder." buttons {"OK"} default button "OK"'
        exit 1
    fi

    # Create an AppleScript list with repo names
    repo_list=""
    for i in "${!folders[@]}"; do
        folder_name=$(basename "${folders[$i]}")
        repo_list="$repo_list\"$folder_name\", "
    done

    # If "New" option is enabled, add it to the list
    if [ "$enable_new" == "true" ]; then
        repo_list="$repo_list\"New\""
    else
        # Remove the trailing comma and space if "New" is not added
        repo_list="${repo_list%, }"
    fi

    # Use AppleScript to display a dialog with the repo options
    selected_repo=$(osascript -e "choose from list {$repo_list} with prompt \"$prompt_text\"")
    log_message "Selected repo from prompt: $selected_repo"

    # Check if the user selected "New" (only if enabled)
    if [ "$selected_repo" == "false" ]; then
        # User pressed cancel
        exit 0
    elif [ "$enable_new" == "true" ] && [ "$selected_repo" == "New" ]; then
        # Ask the user to input a new repository name
        selected_repo=$(osascript -e 'display dialog "Enter the name of the new repository:" default answer ""' -e 'text returned of result')

        # Create the new repository folder
        #mkdir -p "$CHECKEDOUT_FOLDER/$selected_repo"
    fi

    # Navigate to the selected or newly created repository
    cd "$CHECKEDOUT_FOLDER/$selected_repo"

    log_message "Final selected repo: $selected_repo"
    log_message " //// END SELECT_REPO \\\\"
}