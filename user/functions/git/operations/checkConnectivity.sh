# Function to check connectivity to the remote repository
check_connectivity() {
    # Try to fetch from origin with a simple check
    show_details "Checking connectivity to server..."
    fetch_output=$(git fetch origin 2>&1)
    fetch_status=$?
    
    if [ $fetch_status -eq 0 ]; then
        show_details "Connectivity check successful"
        show_git_output "$fetch_output" "fetch"
        return 0  # Success
    else
        log_message "Connectivity check failed: $fetch_output"
        show_details "Connectivity check failed: $fetch_output"
        show_git_output "$fetch_output" "fetch"
        return 1  # Failed
    fi
}