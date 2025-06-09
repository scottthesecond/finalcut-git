# Function to check if files in the repository are open, excluding certain processes
check_open_files() {

    log_message "(BEGIN CHECK_OPEN_FILES)"

    open_files=$(lsof +D "$CHECKEDOUT_FOLDER/$selected_repo" | grep -v "^COMMAND" | grep -vE "(bash|lsof|awk|grep|mdworker_|osascript)")
    if [ -n "$open_files" ]; then
        log_message "Files are still open:"
        log_message "$open_files"
        return 0  # Files are open
    else
        log_message "No files are open."
        return 1  # No files are open
    fi
}