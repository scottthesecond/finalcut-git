#!/bin/bash

read -p "Enter the project name: " project_name
repo_path="$HOME/repositories/$project_name.git"

# Create the repositories directory if it doesn't exist
if [ ! -d "$HOME/repositories" ]; then
  mkdir -p "$HOME/repositories"
fi

# Check if the repository already exists
if [ -d "$repo_path" ]; then
  echo "A repository with that name already exists."
  exit 1
fi

# Create the repository
git init --bare "$repo_path"
chown git:git "$repo_path"

# Clone the bare repository into a temporary directory
temp_dir=$(mktemp -d)
git clone "$repo_path" "$temp_dir"

# Change into the temporary directory
cd "$temp_dir"

# Create a .gitignore to ignore final cut things we don't want to sync
cat <<EOL > .gitignore
**/Render Files
**/Original Media
**/Transcoded Media.
.lock
.lock-info
**/.lock-dir
EOL

# Add and commit the .gitignore file to the cloned repository
git add .gitignore
git commit -m "Add .gitignore file"

# Push the commit back to the bare repository
git push origin master

# Remove temp dir
cd ..
rm -rf "$temp_dir"

# Output success message
echo "Bare repository '$project_name' created in $repo_path with a .gitignore file."