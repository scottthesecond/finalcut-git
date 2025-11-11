#!/bin/bash

# Loops over all repositories in ~/repositories directory and prints their name and size.

declare -a repos_info
total_size=0

REPO_BASE_DIR=~/repositories
for repo in "$REPO_BASE_DIR"/*; do
    if [ -d "$repo" ] && [ -d "$repo/objects" ] && [ -f "$repo/HEAD" ]; then
        # Get the size of the bare repository in human-readable format
        REPO_SIZE=$(du -sh "$repo" 2>/dev/null | cut -f1)
        REPO_NAME=$(basename "$repo")

        # Store the repository size and name
        repos_info+=("$REPO_SIZE $REPO_NAME")

        # Add size to total (in KB) to compute at the end
        total_size_kb=$(du -sk "$repo" 2>/dev/null | cut -f1)
        total_size=$((total_size + total_size_kb))
    fi
done

# Sort the repositories by size and print them
echo "Repositories sorted by size (smallest to largest):"
printf "%s\n" "${repos_info[@]}" | sort -hr | while read -r repo_info; do
    size_human=$(echo "$repo_info" | cut -d ' ' -f1)
    repo_name=$(echo "$repo_info" | cut -d ' ' -f2-)
    echo "$repo_name: $size_human"
done

# Convert total size to human-readable format from kilobytes
total_size_human=$(numfmt --from=iec --to=iec-i --suffix=B <<< "$((total_size * 1024))")
echo -e "\nTotal size of all repositories: $total_size_human"