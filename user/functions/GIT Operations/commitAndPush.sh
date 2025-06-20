commitAndPush() {
    log_message "(BEGIN COMMITANDPUSH)"

    # Get the current date and the user's name
    current_date=$(date +"%Y-%m-%d")
    user_name=$(whoami)

    # Get Commit Message - either from parameter or from CHECKEDOUT file
    if [ -n "$1" ]; then
        commit_message="$1"
    else
        commit_message_user=$(grep 'commit_message=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
        
        if [ -z "$commit_message_user" ]; then
            commit_message="Commit on $current_date by $user_name"
        else
            commit_message="$user_name: $commit_message_user"
        fi
    fi

    # Check if we're ahead of origin
    if git status | grep -q "Your branch is ahead of 'origin/master'"; then
        log_message "Local branch is ahead of origin, attempting to push first"
        show_details "Pushing ahead commits..."
        push_output=$(git push 2>&1)
        push_status=$?
        if [ $push_status -ne 0 ]; then
            log_message "Failed to push ahead commits"
            show_details "Push failed: $push_output"
            show_git_output "$push_output" "push"
            return 1  # Treat this as a conflict
        else
            show_details "Ahead commits pushed successfully"
            show_git_output "$push_output" "push"
        fi
    fi

    # Check for unstaged changes
    log_message "Checking for unstaged changes in $selected_repo"
    show_details "Checking for changes to commit..."
    if git diff-index --quiet HEAD -- && [ -z "$(git status --porcelain)" ]; then
        log_message "No changes to commit in $selected_repo."
        show_details "No changes to commit"
        return 0
    fi

    if ! check_connectivity; then
        log_message "No connectivity to origin for $selected_repo, skipping checkpoint."
        show_details "No connectivity to server, skipping checkpoint"
        return 2
    fi

    # Stage all changes
    log_message "Staging changes in $selected_repo"
    show_details "Staging changes..."
    stage_output=$(git add . 2>&1)
    stage_status=$?
    if [ $stage_status -ne 0 ]; then
        log_message "Failed to stage changes in $selected_repo"
        show_details "Failed to stage changes: $stage_output"
        show_git_output "$stage_output" "add"
        return 2  # Staging error
    else
        show_details "Changes staged successfully"
        show_git_output "$stage_output" "add"
    fi

    # Commit with the message and push
    log_message "Committing changes in $selected_repo"
    show_details "Committing changes..."
    commit_output=$(git commit -m "$commit_message" 2>&1)
    commit_status=$?
    if [ $commit_status -ne 0 ]; then
        log_message "Git commit failed in $selected_repo"
        show_details "Commit failed: $commit_output"
        show_git_output "$commit_output" "commit"
        return 2  # Commit error
    else
        show_details "Changes committed successfully"
        show_git_output "$commit_output" "commit"
    fi

    log_message "Pushing changes for $selected_repo"
    show_details "Pushing changes to server..."
    push_output=$(git push 2>&1)
    push_status=$?
    
    if [ $push_status -ne 0 ]; then
        log_message "Git push failed for $selected_repo"
        show_details "Push failed: $push_output"
        show_git_output "$push_output" "push"
        # Check if it's a conflict error
        if echo "$push_output" | grep -q "rejected\|conflict\|diverged"; then
            return 1  # Conflict error
        else
            return 2  # Other push error
        fi
    else
        show_details "Changes pushed successfully"
        show_git_output "$push_output" "push"
    fi
    
    log_message "Changes have been successfully checked in and pushed for $selected_repo."
    log_message "(END COMMITANDPUSH)"
    return 0
}