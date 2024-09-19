#!/bin/bash

# Ask for the name of the project
read -p "Enter the project name: " project_name

# Define the repository path
repo_path="$HOME/repositories/$project_name.git"

# Check if the repository already exists
if [ -d "$repo_path" ]; then
  echo "A repository with that name already exists."
  exit 1
fi

# Create the new repository directory
mkdir "$repo_path"
chown "$repo_path"
cd "$repo_path"

# Initialize the git repository
git init

# Create FCP .gitignore 
cat <<EOL > .gitignore
**/Render Files
**/Original Media
**/Transcoded Media
EOL
git add .gitignore
git commit -m "Add .gitignore file"

echo "Repository '$project_name' created in $repo_path with a .gitignore file."