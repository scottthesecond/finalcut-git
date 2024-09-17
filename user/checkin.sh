#!/bin/bash

# Load the .env file (for server and port if needed)
if [ -f "$HOME/fcp-git/.env" ]; then
    export $(grep -v '^#' "$HOME/fcp-git/.env" | xargs)
else
    echo ".env file not found in $HOME/fcp-git!"
    exit 1
fi

# Get the directory where the repos are stored
REPO_DIR="$HOME/fcp-git/repos"

# Check if the repository is passed as an argument
if [ -n "$1" ]; then
    selected_repo="$1"
    echo "Repository passed from checkout script: $selected_repo"
    cd "$REPO_DIR/$selected_repo" || exit 1
else
    # Function to display the menu and allow the user to select a repo
    select_repo() {
        echo "Select an existing repository to check in:"
        echo "-----------------------------------------------------------"

        # List all folders inside the repos directory
        folders=("$REPO_DIR"/*)
        if [ ${#folders[@]} -eq 0 ]; then
            echo "No repositories found in $REPO_DIR"
            exit 1
        else
            for i in "${!folders[@]}"; do
                folder_name=$(basename "${folders[$i]}")
                echo "$((i+1))) $folder_name"
            done
        fi

        # Prompt user for selection
        echo ""
        read -p "Enter your choice [1-${#folders[@]}]: " choice

        # Handle user input
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#folders[@]}" ]; then
            selected_repo=$(basename "${folders[$((choice-1))]}")
            echo "You selected repository: $selected_repo"
            cd "$REPO_DIR/$selected_repo" || exit 1
        else
            echo "Invalid option. Exiting."
            exit 1
        fi
    }

    # Run the function to select a repo if none was passed
    select_repo
fi

# Get the current date and the user's name
current_date=$(date +"%Y-%m-%d")
user_name=$(whoami)

# Stage all changes, commit with the current date and username, and push
git add .
git commit -m "Commit on $current_date by $user_name"
git push

echo "Changes have been checked in and pushed for $selected_repo."