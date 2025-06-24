# Function to set the checked out status in .CHECKEDOUT file
# Parameters:
#   $1: user - The username of the person checking out
#   $2: message - The commit message explaining the checkout
#   $3: repo_path - Path to the repository
# Returns:
#   0: Success
#   1: Error
set_checkedout_status() {
    # Validate required parameters
    if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
        log_message "Error: Missing required parameters in set_checkedout_status"
        return $RC_ERROR
    fi

    local user="$1"
    local message="$2"
    local repo_path="$3"
    
    # Validate repository path
    if [ ! -d "$repo_path" ]; then
        log_message "Error: Repository path does not exist: $repo_path"
        return $RC_ERROR
    fi
    
    # Create or update .CHECKEDOUT file
    if ! echo "checked_out_by=$user" > "$repo_path/.CHECKEDOUT"; then
        log_message "Error: Failed to create .CHECKEDOUT file in $repo_path"
        return $RC_ERROR
    fi
    if ! echo "commit_message=$message" >> "$repo_path/.CHECKEDOUT"; then
        log_message "Error: Failed to write commit message to .CHECKEDOUT file"
        return $RC_ERROR
    fi
    
    # Add timestamp
    local current_time=$(date "+%m/%d %H:%M")
    if ! echo "LAST_COMMIT=$current_time" >> "$repo_path/.CHECKEDOUT"; then
        log_message "Error: Failed to write timestamp to .CHECKEDOUT file"
        return $RC_ERROR
    fi
    
    log_message "Successfully set checkout status for $repo_path"
    return $RC_SUCCESS
}

# Function to get the checked out status from .CHECKEDOUT file
# Parameters:
#   $1: repo_path - Path to the repository
# Returns:
#   Success: "user|message|timestamp"
#   Error: Empty string
get_checkedout_status() {
    # Validate required parameters
    if [ -z "$1" ]; then
        log_message "Error: Missing repository path in get_checkedout_status"
        echo ""
        return $RC_ERROR
    fi

    local repo_path="$1"
    local checkedout_file="$repo_path/.CHECKEDOUT"
    
    # Check for both old and new format files
    if [ -f "$repo_path/CHECKEDOUT" ]; then
        log_message "Found legacy CHECKEDOUT file in $repo_path"
        checkedout_file="$repo_path/CHECKEDOUT"
    elif [ ! -f "$checkedout_file" ]; then
        log_message "No .CHECKEDOUT file found in $repo_path"
        echo ""
        return $RC_SUCCESS
    fi
    
    # Read the values, with fallbacks for missing fields
    local checked_out_by=$(grep 'checked_out_by=' "$checkedout_file" | cut -d '=' -f 2 || echo "")
    local commit_message=$(grep 'commit_message=' "$checkedout_file" | cut -d '=' -f 2 || echo "")
    local last_commit=$(grep 'LAST_COMMIT=' "$checkedout_file" | cut -d '=' -f 2 || echo "")
    
    # Validate required fields
    if [ -z "$checked_out_by" ]; then
        log_message "Error: Missing checked_out_by in .CHECKEDOUT file"
        echo ""
        return $RC_ERROR
    fi
    
    echo "$checked_out_by|$commit_message|$last_commit"
    return $RC_SUCCESS
}

# Function to remove .CHECKEDOUT file
# Parameters:
#   $1: repo_path - Path to the repository
# Returns:
#   0: Success
#   1: Error
remove_checkedout_file() {
    # Validate required parameters
    if [ -z "$1" ]; then
        log_message "Error: Missing repository path in remove_checkedout_file"
        return $RC_ERROR
    fi

    local repo_path="$1"
    
    # Validate repository path
    if [ ! -d "$repo_path" ]; then
        log_message "Error: Repository path does not exist: $repo_path"
        return $RC_ERROR
    fi
    
    # Remove both old and new format files
    rm -f "$repo_path/CHECKEDOUT"  # V1 CHECKEDOUT File
    rm -f "$repo_path/.CHECKEDOUT" # V2 .CHECKEDOUT File
    
    # Verify files were removed
    if [ -f "$repo_path/CHECKEDOUT" ] || [ -f "$repo_path/.CHECKEDOUT" ]; then
        log_message "Error: Failed to remove .CHECKEDOUT files from $repo_path"
        return $RC_ERROR
    fi
    
    log_message "Successfully removed .CHECKEDOUT files from $repo_path"
    return $RC_SUCCESS
}