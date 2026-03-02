#!/bin/bash

# Creates the shared motion-templates bare repository on the git server.
# Unlike create-repo.sh, this does NOT add a .gitignore — the templates repo
# manages its own .gitignore via the .sync-include config file.

repo_name="${1:-motion-templates}"
repo_path="$HOME/repositories/$repo_name.git"

# Create the repositories directory if it doesn't exist
if [ ! -d "$HOME/repositories" ]; then
    mkdir -p "$HOME/repositories"
fi

# Check if the repository already exists
if [ -d "$repo_path" ]; then
    echo "A repository named '$repo_name' already exists at $repo_path"
    exit 1
fi

# Create bare repository
git init --bare "$repo_path"
chown git:git "$repo_path"

echo "Templates repository '$repo_name' created at $repo_path"
echo ""
echo "Next steps:"
echo "  1. On each team member's machine, open UNFLab"
echo "  2. Go to Motion Templates > Enable Motion Templates"
echo "  3. Use 'Add Template Folder...' to opt folders in to sync"
