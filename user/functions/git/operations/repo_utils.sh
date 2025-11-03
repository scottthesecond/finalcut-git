# Repository utility functions for common operations
# This file contains shared functions used across multiple scripts

# Function to get list of repositories from a specified folder
# Parameters:
#   $1: folder_path - Path to the folder containing repositories
#   $2: filter_type - Optional filter type ("checkedout", "checkedin", "all")
# Returns:
#   Array of repository names (space-separated string)
get_repo_list() {
    local folder_path="$1"
    local filter_type="${2:-all}"
    local repos=()
    
    # Validate folder path
    if [ ! -d "$folder_path" ]; then
        log_message "Warning: Folder does not exist: $folder_path"
        echo ""
        return $RC_SUCCESS
    fi
    
    # Get all folders in the specified directory
    local folders=("$folder_path"/*)
    
    # Check if there are any repositories
    if [ ${#folders[@]} -eq 0 ]; then
        log_message "No repositories found in: $folder_path"
        echo ""
        return $RC_SUCCESS
    fi
    
    # Filter and process folders
    for folder in "${folders[@]}"; do
        if [ -d "$folder" ]; then
            local repo_name=$(basename "$folder")
            
            # Apply filters if specified
            case "$filter_type" in
                "checkedout")
                    # Only include if currently checked out
                    if [ -d "$CHECKEDOUT_FOLDER/$repo_name" ]; then
                        repos+=("$repo_name")
                    fi
                    ;;
                "checkedin")
                    # Only include if not currently checked out
                    if [ ! -d "$CHECKEDOUT_FOLDER/$repo_name" ]; then
                        repos+=("$repo_name")
                    fi
                    ;;
                "all"|*)
                    # Include all repositories
                    repos+=("$repo_name")
                    ;;
            esac
        fi
    done
    
    echo "${repos[@]}"
    return $RC_SUCCESS
}

# Function to get checked out repositories
# Returns:
#   Array of currently checked out repository names
get_checkedout_repos() {
    get_repo_list "$CHECKEDOUT_FOLDER" "checkedout"
}

# Function to get checked in repositories (not currently checked out)
# Returns:
#   Array of checked in repository names
get_checkedin_repos() {
    get_repo_list "$CHECKEDIN_FOLDER" "checkedin"
}

# Function to get all available repositories (both checked in and out)
# Returns:
#   Array of all repository names
get_all_repos() {
    local checkedout_repos=($(get_checkedout_repos))
    local checkedin_repos=($(get_checkedin_repos))
    local all_repos=("${checkedout_repos[@]}" "${checkedin_repos[@]}")
    
    echo "${all_repos[@]}"
}

# Function to check if a repository exists in a specific folder
# Parameters:
#   $1: repo_name - Name of the repository
#   $2: folder_path - Path to check (defaults to CHECKEDOUT_FOLDER)
# Returns:
#   0: Repository exists
#   1: Repository does not exist
repo_exists() {
    local repo_name="$1"
    local folder_path="${2:-$CHECKEDOUT_FOLDER}"
    
    if [ -d "$folder_path/$repo_name" ]; then
        return $RC_SUCCESS
    else
        return $RC_ERROR
    fi
}

# Function to get repository path
# Parameters:
#   $1: repo_name - Name of the repository
#   $2: folder_type - Type of folder ("checkedout", "checkedin", "auto")
# Returns:
#   Full path to the repository
get_repo_path() {
    local repo_name="$1"
    local folder_type="${2:-auto}"
    
    case "$folder_type" in
        "checkedout")
            echo "$CHECKEDOUT_FOLDER/$repo_name"
            ;;
        "checkedin")
            echo "$CHECKEDIN_FOLDER/$repo_name"
            ;;
        "auto"|*)
            # Auto-detect: check checkedout first, then checkedin
            if repo_exists "$repo_name" "$CHECKEDOUT_FOLDER"; then
                echo "$CHECKEDOUT_FOLDER/$repo_name"
            elif repo_exists "$repo_name" "$CHECKEDIN_FOLDER"; then
                echo "$CHECKEDIN_FOLDER/$repo_name"
            else
                echo ""
            fi
            ;;
    esac
}

# Function to get repository status information
# Parameters:
#   $1: repo_name - Name of the repository
# Returns:
#   Status string: "checkedout|user|message|timestamp" or "checkedin" or "not_found"
get_repo_status() {
    local repo_name="$1"
    local repo_path=""
    
    # Check if repository is checked out
    if repo_exists "$repo_name" "$CHECKEDOUT_FOLDER"; then
        repo_path="$CHECKEDOUT_FOLDER/$repo_name"
        local status=$(get_checkedout_status "$repo_path")
        if [ -n "$status" ]; then
            echo "checkedout|$status"
        else
            echo "checkedout|unknown|unknown|unknown"
        fi
    elif repo_exists "$repo_name" "$CHECKEDIN_FOLDER"; then
        echo "checkedin"
    else
        echo "not_found"
    fi
}

# Function to count repositories in a folder
# Parameters:
#   $1: folder_path - Path to count repositories in
# Returns:
#   Number of repositories
count_repos() {
    local folder_path="$1"
    local repos=($(get_repo_list "$folder_path"))
    echo "${#repos[@]}"
}

# Function to check if any repositories exist in a folder
# Parameters:
#   $1: folder_path - Path to check
# Returns:
#   0: Repositories exist
#   1: No repositories exist
has_repos() {
    local folder_path="$1"
    local count=$(count_repos "$folder_path")
    
    if [ "$count" -gt 0 ]; then
        return $RC_SUCCESS
    else
        return $RC_ERROR
    fi
}

# Function to get the expected remote URL for a repository based on current config
# Parameters:
#   $1: repo_name - Name of the repository
# Returns:
#   Expected remote URL string
get_expected_remote_url() {
    local repo_name="$1"
    
    # Build the expected URL from current config
    echo "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$repo_name.git"
}

# Function to check if repository remote URL matches current config
# Parameters:
#   $1: repo_name - Name of the repository
#   $2: repo_path - Path to the repository directory
# Returns:
#   0: Remote URL matches current config
#   1: Remote URL does not match (or error)
check_remote_url_matches() {
    local repo_name="$1"
    local repo_path="$2"
    
    # Validate inputs
    if [ -z "$repo_name" ] || [ -z "$repo_path" ]; then
        log_message "Error: Missing required parameters in check_remote_url_matches"
        return 1
    fi
    
    # Change to repository directory
    if ! cd "$repo_path"; then
        log_message "Error: Failed to change to repository directory: $repo_path"
        return 1
    fi
    
    # Get current remote URL
    local current_url=$(git remote get-url origin 2>&1)
    local git_status=$?
    
    if [ $git_status -ne 0 ]; then
        log_message "Error: Failed to get remote URL for $repo_name: $current_url"
        return 1
    fi
    
    # Get expected remote URL
    local expected_url=$(get_expected_remote_url "$repo_name")
    
    # Compare URLs
    if [ "$current_url" = "$expected_url" ]; then
        log_message "Repository $repo_name remote URL matches: $expected_url"
        return 0
    else
        log_message "Repository $repo_name remote URL mismatch:"
        log_message "  Current:  $current_url"
        log_message "  Expected: $expected_url"
        return 1
    fi
}

# Function to add SSH host key to known_hosts automatically
# Parameters:
#   $1: server_address - Server address to add
#   $2: server_port - Server port (default: 22)
# Returns:
#   0: Success or already exists
#   1: Error
add_ssh_host_key() {
    local server_address="$1"
    local server_port="${2:-22}"
    
    # Validate inputs
    if [ -z "$server_address" ]; then
        log_message "Error: Missing required server address in add_ssh_host_key"
        return 1
    fi
    
    # Ensure .ssh directory exists
    if [ ! -d "$HOME/.ssh" ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
    fi
    
    # Ensure known_hosts exists
    if [ ! -f "$HOME/.ssh/known_hosts" ]; then
        touch "$HOME/.ssh/known_hosts"
        chmod 600 "$HOME/.ssh/known_hosts"
    fi
    
    # Check if host key already exists
    if ssh-keygen -F "[$server_address]:$server_port" >/dev/null 2>&1 || \
       ssh-keygen -F "$server_address:$server_port" >/dev/null 2>&1; then
        log_message "SSH host key for [$server_address]:$server_port already exists"
        return 0
    fi
    
    # Add host key using ssh-keyscan
    log_message "Adding SSH host key for [$server_address]:$server_port"
    local keyscan_output=$(ssh-keyscan -p "$server_port" "$server_address" 2>&1)
    local keyscan_status=$?
    
    if [ $keyscan_status -eq 0 ]; then
        echo "$keyscan_output" >> "$HOME/.ssh/known_hosts"
        chmod 600 "$HOME/.ssh/known_hosts"
        log_message "Successfully added SSH host key for [$server_address]:$server_port"
        return 0
    else
        log_message "Warning: Failed to scan SSH host key for [$server_address]:$server_port: $keyscan_output"
        # Don't fail - the connection might still work if the user accepts it manually
        return 0
    fi
}

# Function to update repository remote URL to match current config
# Parameters:
#   $1: repo_name - Name of the repository
#   $2: repo_path - Path to the repository directory
# Returns:
#   0: Success
#   1: Error
update_remote_url() {
    local repo_name="$1"
    local repo_path="$2"
    
    # Validate inputs
    if [ -z "$repo_name" ] || [ -z "$repo_path" ]; then
        log_message "Error: Missing required parameters in update_remote_url"
        return 1
    fi
    
    # Add SSH host key to known_hosts if it's not already there
    log_message "Ensuring SSH host key for $SERVER_ADDRESS:$SERVER_PORT is in known_hosts"
    add_ssh_host_key "$SERVER_ADDRESS" "$SERVER_PORT"
    
    # Change to repository directory
    if ! cd "$repo_path"; then
        log_message "Error: Failed to change to repository directory: $repo_path"
        return 1
    fi
    
    # Get expected remote URL
    local expected_url=$(get_expected_remote_url "$repo_name")
    
    # Update remote URL
    local update_output=$(git remote set-url origin "$expected_url" 2>&1)
    local git_status=$?
    
    if [ $git_status -ne 0 ]; then
        log_message "Error: Failed to update remote URL for $repo_name: $update_output"
        return 1
    fi
    
    log_message "Updated repository $repo_name remote URL to: $expected_url"
    return 0
} 