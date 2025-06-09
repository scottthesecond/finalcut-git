# Function to check connectivity to the remote repository
check_connectivity() {
    # Try to fetch from origin with a simple check
    if git fetch origin 2>&1; then
        return 0  # Success
    else
        local error_msg=$(git fetch origin 2>&1)
        log_message "Connectivity check failed: $error_msg"
        return 1  # Failed
    fi
}