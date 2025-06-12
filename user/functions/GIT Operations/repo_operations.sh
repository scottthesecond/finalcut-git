# Constants for operation types
readonly OP_CHECKIN="checkin"
readonly OP_CHECKPOINT="checkpoint"
readonly OP_CHECKPOINT_ALL="checkpoint_all"

# Function to handle common repository operations
# Parameters:
#   $1: operation_type - Type of operation (checkin, checkpoint, checkpoint_all)
#   $2: repo_name - Name of the repository
#   $3: commit_message - Optional commit message (used for checkin)
#   $4: should_remove_checkedout - Whether to remove .CHECKEDOUT file (true/false)
# Returns:
#   0: Success
#   1: Error
handle_repo_operation() {
    # Validate required parameters
    if [ -z "$1" ] || [ -z "$2" ]; then
        log_message "Error: Missing required parameters in handle_repo_operation"
        return $RC_ERROR
    fi

    local operation="$1"
    local repo_name="$2"
    local commit_message="$3"
    local should_remove_checkedout="$4"
    
    # Validate operation type
    if [ "$operation" != "$OP_CHECKIN" ] && [ "$operation" != "$OP_CHECKPOINT" ] && [ "$operation" != "$OP_CHECKPOINT_ALL" ]; then
        log_message "Error: Invalid operation type: $operation"
        return $RC_ERROR
    fi
    
    # Check connectivity before proceeding
    if ! check_connectivity; then
        log_message "No connectivity to origin for $repo_name"
        osascript -e "display dialog \"Unable to connect to the server. Please check your internet connection and try again.\" buttons {\"OK\"} default button \"OK\""
        return $RC_ERROR
    fi
    
    # For checkin, verify no open files
    if [ "$operation" = "$OP_CHECKIN" ]; then
        while check_open_files; do
            user_choice=$(osascript -e "display dialog \"There are files in this repository that are still open in other applications.  Please make sure everything is closed before checking in.\n\nYou can check the log to see which applications are using files in the repository.\" buttons {\"Check-in Anyway (This is a bad idea)\", \"I've Closed Them\"} default button \"I've Closed Them\"")
            
            if [[ "$user_choice" == "button returned:Check-in Anyway (This is a bad idea)" ]]; then
                log_message "User chose to proceed with check-in despite open files."
                break
            fi
        done
    fi
    
    # Update timestamp if needed
    if [ "$operation" = "$OP_CHECKPOINT" ] || [ "$operation" = "$OP_CHECKPOINT_ALL" ]; then
        update_checkin_time "$CHECKEDOUT_FOLDER/$repo_name"
    fi
    
    # Remove checkedout file if needed
    if [ "$should_remove_checkedout" = "true" ]; then
        remove_checkedout_file "$CHECKEDOUT_FOLDER/$repo_name"
    fi
    
    # For checkpoints or checkpoint_all operations, use the saved commit message
    if [ "$operation" = "$OP_CHECKPOINT" ] || [ "$operation" = "$OP_CHECKPOINT_ALL" ]; then
        commitAndPush
    else
        # For regular checkin, use the provided commit message
        if [ -n "$commit_message" ]; then
            commitAndPush "$commit_message"
        else
            commitAndPush
        fi
    fi
    push_status=$?
    
    if [ $push_status -eq 1 ]; then
        # If push fails with a conflict, handle it
        handle_git_conflict "$CHECKEDOUT_FOLDER/$repo_name"
        return $RC_ERROR
    elif [ $push_status -eq 2 ]; then
        # If there's another type of error, show a generic error
        handle_error "There was an error while trying to sync your changes. Please check the log for details."
        return $RC_ERROR
    fi
    
    # Move to checkedin folder if this is a checkin
    if [ "$operation" = "$OP_CHECKIN" ]; then
        moveToHiddenCheckinFolder
    fi
    
    return $RC_SUCCESS
}

# Function to get commit message from user
# Parameters:
#   $1: default_message - Optional default message to show
#   $2: title - Dialog title
#   $3: prompt - Dialog prompt text
#   $4: repo_name - Optional repository name to look up default message
# Returns:
#   0: Success, message is output
#   1: User canceled
#   2: Error
get_commit_message() {
    # Validate required parameters
    if [ -z "$2" ] || [ -z "$3" ]; then
        log_message "Error: Missing required parameters in get_commit_message"
        return $RC_ERROR
    fi

    local default_message="$1"
    local title="$2"
    local prompt="$3"
    local repo_name="$4"
    
    # If no default message provided but repo_name is, try to get it from .CHECKEDOUT
    if [ -z "$default_message" ] && [ -n "$repo_name" ]; then
        local checkedout_file="$CHECKEDOUT_FOLDER/$repo_name/.CHECKEDOUT"
        if [ -f "$checkedout_file" ]; then
            default_message=$(grep 'commit_message=' "$checkedout_file" | cut -d '=' -f 2)
            log_message "Found default commit message from .CHECKEDOUT: $default_message"
        fi
    fi
    
    # In silent mode, just return the default message if we have one
    if [ "$SILENT_MODE" = true ]; then
        if [ -n "$default_message" ]; then
            echo "[Automatic Checkin] $default_message"
            return $RC_SUCCESS
        else
            # If no default message in silent mode, use a generic one
            echo "[Automatic Checkin]"
            return $RC_SUCCESS
        fi
    fi
    
    # Escape special characters for osascript
    prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed "s/'/\\'/g")
    title=$(echo "$title" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed "s/'/\\'/g")
    default_message=$(echo "$default_message" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed "s/'/\\'/g")
    
    # Build the osascript command
    local osascript_cmd
    if [ -n "$default_message" ]; then
        osascript_cmd="display dialog \"$prompt\" default answer \"$default_message\" with title \"$title\" buttons {\"Cancel\", \"OK\"} default button \"OK\""
    else
        osascript_cmd="display dialog \"$prompt\" default answer \"\" with title \"$title\" buttons {\"Cancel\", \"OK\"} default button \"OK\""
    fi
    
    # Run osascript and capture both output and error
    result=$(osascript -e "$osascript_cmd" 2>&1)
    osascript_status=$?
    
    # Check if osascript failed
    if [ $osascript_status -ne 0 ]; then
        log_message "Error: Failed to display commit message dialog. Status: $osascript_status, Error: $result"
        return $RC_ERROR
    fi
    
    # Parse the result
    button_clicked=$(echo "$result" | sed -n 's/.*button returned:\(.*\), text returned.*/\1/p' | tr -d ', ')
    commit_message=$(echo "$result" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')
    
    if [ "$button_clicked" = "Cancel" ]; then
        log_message "User canceled commit message dialog"
        return $RC_CANCEL
    fi
    
    echo "$commit_message"
    return $RC_SUCCESS
} 