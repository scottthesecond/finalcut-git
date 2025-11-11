#!/bin/bash

# Set the base directory where all the bare repositories are located
BASE_DIR="$HOME/repositories"  # Replace ~/ with $HOME for proper expansion

# Set the path to the new .gitignore file
NEW_GITIGNORE="$HOME/scripts/gitignore-template"  # Replace ~/ with $HOME for proper expansion

# Loop through each directory in the base directory
for REPO_DIR in "$BASE_DIR"/*; do
    if [ -d "$REPO_DIR" ]; then
        echo "Updating .gitignore in repository: $REPO_DIR"

        # Create a temporary directory using mktemp
        TEMP_DIR=$(mktemp -d)

        # Clone the repository into the temporary directory
        git clone "$REPO_DIR" "$TEMP_DIR"
        
        if [ $? -ne 0 ]; then
            echo "Failed to clone $REPO_DIR. Skipping."
            # Remove the temporary directory and continue with the next repo
            rm -rf "$TEMP_DIR"
            continue
        fi

        cd "$TEMP_DIR" || exit

        # Replace the .gitignore file with the new one
        cp "$NEW_GITIGNORE" .gitignore

        # Add and commit the new .gitignore
        git add .gitignore
        git commit -m "Update .gitignore"

        # Remove files that match the new .gitignore
        git rm -r --cached .
        git add .
        git commit -m "Remove files matching new .gitignore"

        # Push changes back to the bare repository
        git push origin master
        
        if [ $? -ne 0 ]; then
            echo "Failed to push changes to $REPO_DIR."
        else
            echo "Successfully updated .gitignore in repository $REPO_DIR."
        fi

        # Cleanup the temporary directory
        rm -rf "$TEMP_DIR"

        # Change back to the base directory before processing the next repo
        cd "$BASE_DIR" || exit
    fi
done

echo "All repositories processed."