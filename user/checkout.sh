#!/bin/bash

# Load server and port from the .env file
if [ -f "$HOME/fcp-git/.env" ]; then
    export $(grep -v '^#' "$HOME/fcp-git/.env" | xargs)
else
    echo ".env file not found in $HOME/fcp-git!"
    exit 1
fi

# Check if SERVER_ADDRESS and SERVER_PORT are set
if [ -z "$SERVER_ADDRESS" ] || [ -z "$SERVER_PORT" ]; then
    echo "Server address or port is missing in the .env file."
    exit 1
fi

# Get the directory where the repos are stored
REPO_DIR="$HOME/fcp-git/repos"

# Check if the directory exists
if [ ! -d "$REPO_DIR" ]; then
    echo "The directory $REPO_DIR does not exist! Creating it..."
    mkdir -p "$REPO_DIR"
fi

# Function to display the menu and allow the user to select or enter a new repo
select_repo() {
    echo "Select an existing repository or enter the name of a new one:"
    echo "-----------------------------------------------------------"

    # List all folders inside the repos directory
    folders=("$REPO_DIR"/*)
    if [ ${#folders[@]} -eq 0 ]; then
        echo "No repositories found in $REPO_DIR"
    else
        for i in "${!folders[@]}"; do
            folder_name=$(basename "${folders[$i]}")
            echo "$((i+1))) $folder_name"
        done
    fi

    # Prompt user for selection or new entry
    echo "N) Enter the name of a new repository"
    echo ""
    read -p "Enter your choice [1-${#folders[@]} or N for new]: " choice

    # Handle user input
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#folders[@]}" ]; then
        selected_repo=$(basename "${folders[$((choice-1))]}")
        echo "You selected existing repository: $selected_repo"
        cd "$REPO_DIR/$selected_repo" || exit 1
        echo "Running git pull in $selected_repo..."
        git pull
        # Open the Finder window in the selected repo
        open "$REPO_DIR/$selected_repo"
    elif [[ "$choice" =~ ^[Nn]$ ]]; then
        read -p "Enter the name of the new repository: " new_repo
        git clone "git@$SERVER_ADDRESS:$new_repo.git" "$REPO_DIR/$new_repo"
        echo "New repository cloned: $new_repo"
        # Open the Finder window in the new repo
        open "$REPO_DIR/$new_repo"
    else
        echo "Invalid option. Please try again."
        select_repo
    fi
}

# Run the function to display the selection menu
select_repo
# Inform the user and wait for them to press Enter
echo "You are now checked out into $selected_repo."
read -p "Press Enter when you are done making changes, and the changes will be checked in."

# Automatically call the checkin.sh script to commit and push changes
"$HOME/fcp-git/checkin.sh" "$selected_repo"