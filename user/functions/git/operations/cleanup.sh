# Cleanup functions for managing old repositories

# Function to check if a repository has been accessed recently
# Parameters:
#   $1: repo_path - Path to the repository
#   $2: days_threshold - Number of days to consider "recent" (default: 30)
# Returns:
#   0: Repository has been committed to recently
#   1: Repository has not been committed to recently or has no commits
check_repo_recent_access() {
    local repo_path="$1"
    local days_threshold="${2:-30}"

    # Get the last commit timestamp
    if ! cd "$repo_path"; then
        log_message "Error: Failed to change to repository directory: $repo_path"
        return 1
    fi
    local last_commit_time=$(git log -1 --format=%ct 2>/dev/null)
    if [ -z "$last_commit_time" ]; then
        log_message "No commits found in repository: $repo_path"
        return 1
    fi

    # Calculate the timestamp for the threshold
    local threshold_timestamp=$(date -v-${days_threshold}d +%s)

    # Check if the last commit is within the threshold
    if [ "$last_commit_time" -gt "$threshold_timestamp" ]; then
        local readable_time=$(date -r "$last_commit_time" "+%Y-%m-%d %H:%M:%S")
        log_message "Repository $repo_path committed to recently: $readable_time"
        return 0
    else
        local readable_time=$(date -r "$last_commit_time" "+%Y-%m-%d %H:%M:%S")
        log_message "Repository $repo_path not committed to recently: $readable_time"
        return 1
    fi
}

# Function to check if a repository has uncommitted changes
# Parameters:
#   $1: repo_path - Path to the repository
# Returns:
#   0: Repository has uncommitted changes
#   1: Repository is clean (no uncommitted changes)
check_repo_has_changes() {
    local repo_path="$1"
    
    # Change to repository directory
    if ! cd "$repo_path"; then
        log_message "Error: Failed to change to repository directory: $repo_path"
        return 1
    fi
    
    # Check for unstaged changes
    if ! git diff-index --quiet HEAD -- && [ -n "$(git status --porcelain)" ]; then
        log_message "Repository $repo_path has uncommitted changes"
        return 0
    fi
    
    # Check if we're ahead of origin
    if git status | grep -q "Your branch is ahead of 'origin/master'"; then
        log_message "Repository $repo_path is ahead of origin"
        return 0
    fi
    
    log_message "Repository $repo_path is clean (no uncommitted changes)"
    return 1
}

# Function to check connectivity to git server
# Parameters:
#   $1: repo_path - Path to the repository
# Returns:
#   0: Can connect to server
#   1: Cannot connect to server
check_repo_connectivity() {
    local repo_path="$1"
    
    # Change to repository directory
    if ! cd "$repo_path"; then
        log_message "Error: Failed to change to repository directory: $repo_path"
        return 1
    fi
    
    # Check if we can reach the origin
    if git ls-remote --exit-code origin >/dev/null 2>&1; then
        log_message "Repository $repo_path can connect to origin"
        return 0
    else
        log_message "Repository $repo_path cannot connect to origin"
        return 1
    fi
}

# Function to check if a repository is safe to remove
# Parameters:
#   $1: repo_path - Path to the repository
#   $2: repo_name - Name of the repository
# Returns:
#   0: Safe to remove
#   1: Not safe to remove
check_repo_safe_to_remove() {
    local repo_path="$1"
    local repo_name="$2"
    
    log_message "Checking if repository $repo_name is safe to remove"
    
    # Check if repository exists
    if [ ! -d "$repo_path" ]; then
        log_message "Repository $repo_name does not exist: $repo_path"
        return 1
    fi
    
    # Check if repository has been accessed recently (within 30 days)
    if check_repo_recent_access "$repo_path" 30; then
        log_message "Repository $repo_name has been accessed recently, not safe to remove"
        return 1
    fi
    
    # Check if repository has uncommitted changes
    if check_repo_has_changes "$repo_path"; then
        log_message "Repository $repo_name has uncommitted changes, not safe to remove"
        return 1
    fi
    
    # Check connectivity to server
    if ! check_repo_connectivity "$repo_path"; then
        log_message "Repository $repo_name cannot connect to server, not safe to remove"
        return 1
    fi
    
    log_message "Repository $repo_name is safe to remove"
    return 0
}

# Function to perform cleanup check on all checked-in repositories
# This function is called by the background worker
cleanup_check() {
    log_message "(BEGIN CLEANUP_CHECK)"
    
    # Create operation lock
    if ! create_operation_lock "cleanup_check"; then
        return $RC_ERROR
    fi
    
    # Get all checked-in repositories
    local checkedin_repos=($(get_checkedin_repos))
    log_message "Found ${#checkedin_repos[@]} checked-in repositories"
    
    # Check if there are any repositories
    if [ ${#checkedin_repos[@]} -eq 0 ]; then
        log_message "No checked-in repositories found."
        return $RC_SUCCESS
    fi
    
    # Clear the removable file
    > "$REMOVABLE_FILE"
    
    local removable_count=0
    
    # Check each repository
    for repo_name in "${checkedin_repos[@]}"; do
        local repo_path="$CHECKEDIN_FOLDER/$repo_name"
        log_message "Checking repository: $repo_name"
        
        # Check if repository is safe to remove
        if check_repo_safe_to_remove "$repo_path" "$repo_name"; then
            # Add to removable file
            echo "$repo_name" >> "$REMOVABLE_FILE"
            ((removable_count++))
            log_message "Added $repo_name to removable list"
        fi
    done
    
    log_message "Cleanup check complete. Found $removable_count repositories that can be safely removed"
    
    # If we found removable repositories, log it
    if [ $removable_count -gt 0 ]; then
        log_message "Removable repositories: $(cat "$REMOVABLE_FILE" | tr '\n' ' ')"
    fi
    
    log_message "(END CLEANUP_CHECK)"
    return $RC_SUCCESS
}

# Function to remove a repository from cache
# Parameters:
#   $1: repo_name - Name of the repository to remove
# Returns:
#   0: Success
#   1: Error
remove_repository_from_cache() {
    local repo_name="$1"
    local repo_path="$CHECKEDIN_FOLDER/$repo_name"
    
    log_message "(BEGIN REMOVE_REPOSITORY_FROM_CACHE)"
    log_message "Removing repository $repo_name from cache"
    
    # Validate repository exists
    if [ ! -d "$repo_path" ]; then
        log_message "Error: Repository $repo_name does not exist: $repo_path"
        return $RC_ERROR
    fi
    
    # Double-check it's safe to remove
    if ! check_repo_safe_to_remove "$repo_path" "$repo_name"; then
        log_message "Error: Repository $repo_name is not safe to remove"
        return $RC_ERROR
    fi
    
    # Make repository writable before deletion (checked-in repos are read-only)
    log_message "Making repository writable for deletion..."
    if ! chmod -R u+w "$repo_path"; then
        log_message "Error: Failed to make repository writable: $repo_path"
        return $RC_ERROR
    fi
    
    # Remove the repository
    if rm -rf "$repo_path"; then
        log_message "Successfully removed repository $repo_name from cache"
        
        # Remove from removable file if it exists
        if [ -f "$REMOVABLE_FILE" ]; then
            sed -i '' "/^${repo_name}$/d" "$REMOVABLE_FILE"
            log_message "Removed $repo_name from removable file"
        fi
        
        # Show success notification
        display_notification "Cache Cleanup" "Successfully removed $repo_name from cache"
        
        log_message "(END REMOVE_REPOSITORY_FROM_CACHE)"
        return $RC_SUCCESS
    else
        log_message "Error: Failed to remove repository $repo_name"
        return $RC_ERROR
    fi
}

# Function to get list of removable repositories
# Returns:
#   Array of repository names that can be safely removed
get_removable_repos() {
    if [ -f "$REMOVABLE_FILE" ]; then
        cat "$REMOVABLE_FILE" | grep -v '^$'
    else
        echo ""
    fi
}

# Function to check if there are any removable repositories
# Returns:
#   0: There are removable repositories
#   1: No removable repositories
has_removable_repos() {
    if [ -f "$REMOVABLE_FILE" ] && [ -s "$REMOVABLE_FILE" ]; then
        return $RC_SUCCESS
    else
        return $RC_ERROR
    fi
} 