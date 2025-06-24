# Function to check if any files in the repository have been accessed recently
check_recent_access() {

    log_message "(BEGIN CHECK_RECENT_ACCESS)"

    local repo_path="$CHECKEDOUT_FOLDER/$selected_repo"
    local thirty_mins_ago=$(date -v-30M +%s)
    local has_recent_access=0
    local recent_access_time=0
    local temp_file=$(mktemp)

    # Find all files in the repository (excluding .git directory) and store their access times
    find "$repo_path" -type f -not -path "*/\.*" -exec stat -f "%a" {} \; > "$temp_file"

    # Read the access times and find the most recent
    while IFS= read -r access_time; do
        # If any file has been accessed in the last 30 minutes, set flag
        if [ "$access_time" -gt "$thirty_mins_ago" ]; then
            has_recent_access=1
            recent_access_time=$access_time
        fi
    done < "$temp_file"

    # Clean up temp file
    rm "$temp_file"

    # Get the most recent access time from all files
    most_recent_time=$(find "$repo_path" -type f -not -path "*/\.*" -exec stat -f "%a" {} \; | sort -nr | head -n1)

    # Convert most recent time to readable format
    readable_time=$(date -r "$most_recent_time" "+%Y-%m-%d %H:%M:%S")

    if [ $has_recent_access -eq 1 ]; then
        log_message "Repo has been accessed in the last 30 minutes – we shouldn't try to auto-checkin; let's checkpoint instead."
        log_message "Last Accessed: $readable_time"
    else
        log_message "File has not been accessed in the last 30 minutes."
        log_message "Most Recent Access: $readable_time"
    fi

    return $has_recent_access
}
