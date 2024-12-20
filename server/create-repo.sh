#!/bin/bash

# Set the path to the new .gitignore file
gi_template="$HOME/scripts/gitignore-template"  # Replace ~/ with $HOME for proper expansion


if [ -z "$1" ]; then
  # If no argument is provided, prompt the user
  read -p "Enter the project name: " project_name
else
  project_name="$1"
fi

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

cp "$gi_template" .gitignore

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