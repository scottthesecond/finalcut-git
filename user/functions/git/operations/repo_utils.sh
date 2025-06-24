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