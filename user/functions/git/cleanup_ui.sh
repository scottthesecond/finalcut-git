# Cleanup UI functions

# Function to display cleanup submenu
display_cleanup_submenu() {
    # Check if there are any removable repositories
    if has_removable_repos; then
        local removable_repos=($(get_removable_repos))
        local submenu_items=""
        
        # Add header
        submenu_items="DISABLED|Found ${#removable_repos[@]} project(s) that can be safely removed"
        submenu_items="$submenu_items|----"
        
        # Add each removable repository with days since last commit and size
        for repo_name in "${removable_repos[@]}"; do
            local repo_path="$CHECKEDIN_FOLDER/$repo_name"
            local days_since_commit="unknown"
            local size_str="unknown"

            # Days since last commit
            if [ -d "$repo_path" ]; then
                if cd "$repo_path"; then
                    local last_commit_time=$(git log -1 --format=%ct 2>/dev/null)
                    if [ -n "$last_commit_time" ]; then
                        local now=$(date +%s)
                        local days_ago=$(( (now - last_commit_time) / 86400 ))
                        days_since_commit="$days_ago"
                    fi
                fi
                # Repo size in KB
                local size_kb=$(du -sk . | awk '{print $1}')
                if [ -n "$size_kb" ]; then
                    if [ "$size_kb" -ge 1048576 ]; then
                        # 1GB or more
                        local size_gb=$(echo "scale=1; $size_kb/1048576" | bc)
                        size_str="$size_gb GB"
                    else
                        local size_mb=$(echo "scale=1; $size_kb/1024" | bc)
                        size_str="$size_mb MB"
                    fi
                fi
            fi
            submenu_items="$submenu_items|Remove \"$repo_name\" ($days_since_commit days; $size_str) from cache"
        done
        
        # Output the submenu in Platypus format
        echo "SUBMENU|Cleanup|$submenu_items"
    fi
    # If no removable repositories, output nothing
}

# Function to handle cleanup menu selection
handle_cleanup_menu() {
    local menu_item="$1"
    
    case "$menu_item" in
        Remove\ "*"*from\ cache)
            # Extract repo name using sed (up to first closing quote)
            local repo_name=$(echo "$menu_item" | sed -n 's/^Remove "\([^"]*\)".*/\1/p')
            prompt_remove_repository "$repo_name"
            ;;
        *)
            log_message "Unknown cleanup menu item: $menu_item"
            ;;
    esac
}

# Function to prompt user to confirm repository removal
# Parameters:
#   $1: repo_name - Name of the repository to remove
prompt_remove_repository() {
    local repo_name="$1"
    local repo_path="$CHECKEDIN_FOLDER/$repo_name"
    
    log_message "Prompting user to remove repository: $repo_name"
    
    # Get the last commit time for the message
    local last_commit_days="unknown"
    if [ -d "$repo_path" ]; then
        if cd "$repo_path"; then
            local last_commit_time=$(git log -1 --format=%ct 2>/dev/null)
            if [ -n "$last_commit_time" ]; then
                local now=$(date +%s)
                local days_ago=$(( (now - last_commit_time) / 86400 ))
                last_commit_days="$days_ago"
            fi
        fi
    fi
    
    # Create the dialog message
    local message="You haven't committed to $repo_name in $last_commit_days day(s). It's safe to erase it from your cache."
    
    # Show confirmation dialog
    local result=$(osascript -e "display dialog \"$message\" buttons {\"Cancel\", \"Continue\"} default button \"Cancel\" with title \"Remove from Cache\"")
    
    # Parse the result
    local button_clicked=$(echo "$result" | sed -n 's/.*button returned:\(.*\)/\1/p' | tr -d ', ')
    
    if [ "$button_clicked" = "Continue" ]; then
        log_message "User confirmed removal of repository: $repo_name"
        
        # Remove the repository
        if remove_repository_from_cache "$repo_name"; then
            log_message "Successfully removed repository: $repo_name"
        else
            log_message "Failed to remove repository: $repo_name"
            handle_error "Failed to remove $repo_name from cache"
        fi
    else
        log_message "User cancelled removal of repository: $repo_name"
    fi
}

# Function to run cleanup check manually
run_cleanup_check() {
    log_message "Running manual cleanup check"
    
    # Show progress dialog
    display_dialog_timed "Cache Cleanup" "Checking for old projects that can be safely removed..." "Hide"
    
    # Run the cleanup check
    if cleanup_check; then
        hide_dialog
        
        # Check if any repositories were found
        if has_removable_repos; then
            local removable_repos=($(get_removable_repos))
            local count=${#removable_repos[@]}
            
            if [ $count -eq 1 ]; then
                display_notification "Cache Cleanup" "Found 1 project that can be safely removed"
            else
                display_notification "Cache Cleanup" "Found $count projects that can be safely removed"
            fi
        else
            display_notification "Cache Cleanup" "No projects found that can be safely removed"
        fi
    else
        hide_dialog
        handle_error "Failed to run cleanup check"
    fi
} 