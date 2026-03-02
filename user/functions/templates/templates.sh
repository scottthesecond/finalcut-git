# Motion Templates sync — core logic

# Run a git command against the templates repo (separate git-dir from work-tree)
templates_git() {
    git --git-dir="$TEMPLATES_GIT_DIR" --work-tree="$TEMPLATES_WORK_TREE" "$@"
}

# Returns 0 if the templates repo has been initialised and has a remote
templates_is_initialized() {
    [ -d "$TEMPLATES_GIT_DIR" ] && templates_git remote get-url origin &>/dev/null
}

# Templates-specific connectivity check (uses templates_git, not bare git)
templates_check_connectivity() {
    log_message "Checking templates connectivity..."
    local fetch_output
    fetch_output=$(templates_git fetch origin 2>&1)
    local fetch_status=$?
    if [ $fetch_status -ne 0 ]; then
        log_message "Templates connectivity check failed: $fetch_output"
        return 1
    fi
    return 0
}

# Return the path to the Motion Templates folder
get_motion_templates_path() {
    echo "$TEMPLATES_WORK_TREE"
}

# Return the remote URL for the templates repo
get_templates_remote_url() {
    echo "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$TEMPLATES_REPO_NAME.git"
}

# Generate .gitignore from .sync-include using an ignore-all then un-ignore approach.
# Must be called from a context where TEMPLATES_SYNC_INCLUDE and TEMPLATES_GITIGNORE are set.
generate_templates_gitignore() {
    log_message "Generating templates .gitignore from .sync-include"

    # Start with ignore-all header
    {
        echo "# Auto-generated from .sync-include — do not edit manually"
        echo "*"
        echo "!.gitignore"
        echo "!.sync-include"
    } > "$TEMPLATES_GITIGNORE"

    if [ ! -f "$TEMPLATES_SYNC_INCLUDE" ]; then
        log_message "No .sync-include found, leaving gitignore with just ignore-all"
        return 0
    fi

    while IFS= read -r folder; do
        # Skip blank lines and comments
        [[ -z "$folder" || "$folder" == \#* ]] && continue

        # Strip leading/trailing whitespace
        folder="$(echo "$folder" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

        # Un-ignore each parent directory in the path so git can recurse into it
        IFS='/' read -ra parts <<< "$folder"
        current=""
        for part in "${parts[@]}"; do
            current="${current}${part}"
            echo "!${current}/" >> "$TEMPLATES_GITIGNORE"
            current="${current}/"
        done

        # Un-ignore all contents of the leaf folder
        echo "!${folder}/**" >> "$TEMPLATES_GITIGNORE"
    done < "$TEMPLATES_SYNC_INCLUDE"

    log_message "Templates .gitignore written to $TEMPLATES_GITIGNORE"
}

# Return newline-separated list of currently synced folders (from .sync-include)
templates_list_synced() {
    if [ ! -f "$TEMPLATES_SYNC_INCLUDE" ]; then
        return 0
    fi
    grep -v '^[[:space:]]*$' "$TEMPLATES_SYNC_INCLUDE" | grep -v '^#'
}

# First-time initialisation of the templates repo.
# Expects the bare repo to already exist on the server.
# Returns 0 on success, 1 on failure.
templates_init() {
    log_message "(BEGIN TEMPLATES_INIT)"

    local remote_url
    remote_url="$(get_templates_remote_url)"
    log_message "Remote URL: $remote_url"

    # Create the Motion Templates folder if it doesn't exist
    mkdir -p "$TEMPLATES_WORK_TREE"

    # Create the git dir container
    mkdir -p "$(dirname "$TEMPLATES_GIT_DIR")"

    # Initialise with separate git-dir so .git metadata stays out of the work tree
    show_details "Initialising templates repository..."
    init_output=$(git init --separate-git-dir="$TEMPLATES_GIT_DIR" "$TEMPLATES_WORK_TREE" 2>&1)
    if [ $? -ne 0 ]; then
        log_message "git init failed: $init_output"
        handle_error "Failed to initialise templates repository."
        return $RC_ERROR
    fi

    # Remove the .git file that git init places in the work tree — we don't want it there
    rm -f "$TEMPLATES_WORK_TREE/.git"

    # Point git at the correct work tree (needed when work tree != git-dir parent)
    templates_git config core.worktree "$TEMPLATES_WORK_TREE"

    # Add remote
    show_details "Connecting to server..."
    templates_git remote add origin "$remote_url" 2>/dev/null

    # Try to fetch from server
    show_details "Fetching templates from server..."
    fetch_output=$(templates_git fetch origin 2>&1)
    fetch_status=$?

    if [ $fetch_status -ne 0 ]; then
        log_message "Fetch failed: $fetch_output"
        # Clean up the partial init
        rm -rf "$TEMPLATES_GIT_DIR"
        handle_error "Could not connect to the templates repository on the server.\n\nMake sure the 'motion-templates' repository has been created on the server using create-templates-repo.sh first."
        return $RC_ERROR
    fi

    # Get the local default branch name (git 2.28+ defaults to 'main', older versions use 'master')
    local default_branch
    default_branch=$(templates_git symbolic-ref --short HEAD 2>/dev/null || echo "main")
    log_message "Local default branch: $default_branch"

    # Detect the remote's default branch from available refs
    local remote_branch=""
    local remote_refs
    remote_refs=$(templates_git ls-remote --heads origin 2>/dev/null)
    if echo "$remote_refs" | grep -q "refs/heads/"; then
        # Remote has at least one branch — find which one
        remote_branch=$(templates_git ls-remote --symref origin HEAD 2>/dev/null \
            | grep '^ref:' | sed 's|ref: refs/heads/||;s|[[:space:]].*||')
        if [ -z "$remote_branch" ]; then
            # Fall back: prefer main, then master, then whatever is first
            if echo "$remote_refs" | grep -q "refs/heads/main"; then
                remote_branch="main"
            elif echo "$remote_refs" | grep -q "refs/heads/master"; then
                remote_branch="master"
            else
                remote_branch=$(echo "$remote_refs" | head -1 | sed 's|.*refs/heads/||')
            fi
        fi
        log_message "Remote branch: $remote_branch"

        # Check for pre-existing template folders and back them up before checkout
        local remote_sync_include
        remote_sync_include=$(templates_git show "origin/$remote_branch:.sync-include" 2>/dev/null)
        if [ -n "$remote_sync_include" ]; then
            local backed_up=0
            local timestamp=$(date +"%Y%m%d_%H%M%S")
            local backup_dir="$BACKUPS_FOLDER/templates_$timestamp"

            while IFS= read -r folder; do
                [[ -z "$folder" || "$folder" == \#* ]] && continue
                folder="$(echo "$folder" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                local existing_path="$TEMPLATES_WORK_TREE/$folder"
                if [ -d "$existing_path" ]; then
                    log_message "Pre-existing template folder found: $existing_path"
                    if [ $backed_up -eq 0 ]; then
                        mkdir -p "$backup_dir"
                        show_details "Backing up existing template folders..."
                        log_message "Backing up existing template folders to $backup_dir"
                    fi
                    # Preserve the folder structure in the backup
                    local backup_dest="$backup_dir/$folder"
                    mkdir -p "$(dirname "$backup_dest")"
                    mv "$existing_path" "$backup_dest" 2>&1
                    log_message "Moved $existing_path to $backup_dest"
                    backed_up=$((backed_up + 1))
                fi
            done <<< "$remote_sync_include"

            if [ $backed_up -gt 0 ]; then
                log_message "Backed up $backed_up existing template folder(s) to $backup_dir"
                display_notification "Motion Templates" "$backed_up existing template folder(s) backed up to:\\n$backup_dir" ""
            fi
        fi

        show_details "Checking out templates..."
        checkout_output=$(templates_git checkout -b "$remote_branch" --track "origin/$remote_branch" 2>&1)
        checkout_status=$?
        if [ $checkout_status -ne 0 ]; then
            log_message "Checkout failed: $checkout_output"
            rm -rf "$TEMPLATES_GIT_DIR"
            handle_error "Failed to check out templates from server."
            return $RC_ERROR
        fi
        show_details "Templates loaded successfully"
        log_message "Templates checked out from origin/$remote_branch"
    else
        # Remote is empty — push an initial commit with empty .sync-include
        show_details "Initialising empty templates repository..."
        echo "# Add template folders via UNFlab > Motion Templates > Add Template Folder" > "$TEMPLATES_SYNC_INCLUDE"
        generate_templates_gitignore

        # Force-add so the catch-all '*' in .gitignore doesn't silently block these files
        add_output=$(templates_git add -f "$TEMPLATES_SYNC_INCLUDE" "$TEMPLATES_GITIGNORE" 2>&1)
        add_status=$?
        log_message "git add output: $add_output"
        if [ $add_status -ne 0 ]; then
            log_message "Add failed: $add_output"
            rm -rf "$TEMPLATES_GIT_DIR"
            handle_error "Failed to stage initial templates files."
            return $RC_ERROR
        fi

        commit_output=$(templates_git commit -m "Initial templates sync setup" 2>&1)
        commit_status=$?
        log_message "git commit output: $commit_output"
        if [ $commit_status -ne 0 ]; then
            log_message "Commit failed: $commit_output"
            rm -rf "$TEMPLATES_GIT_DIR"
            handle_error "Failed to create initial templates commit."
            return $RC_ERROR
        fi

        # Push using HEAD so we don't hardcode 'master' — works with both 'main' and 'master'
        push_output=$(templates_git push -u origin HEAD 2>&1)
        if [ $? -ne 0 ]; then
            log_message "Push failed: $push_output"
            rm -rf "$TEMPLATES_GIT_DIR"
            handle_error "Failed to push initial templates setup to server."
            return $RC_ERROR
        fi
        show_details "Templates repository initialised"
        log_message "Pushed initial templates commit on branch: $default_branch"
    fi

    log_message "(END TEMPLATES_INIT)"
    display_notification "Motion Templates" "Templates sync enabled successfully." ""
    return $RC_SUCCESS
}

# Pull the latest templates from the server
templates_pull() {
    log_message "(BEGIN TEMPLATES_PULL)"

    if ! templates_is_initialized; then
        handle_error "Motion Templates sync is not set up yet. Use 'Enable Motion Templates' first."
        return $RC_ERROR
    fi

    if ! templates_check_connectivity; then
        handle_error "Unable to connect to the server. Please check your connection and try again."
        return $RC_ERROR
    fi

    # Determine current branch name
    local branch
    branch=$(templates_git symbolic-ref --short HEAD 2>/dev/null || echo "main")

    show_details "Merging changes..."
    merge_output=$(templates_git merge "origin/$branch" 2>&1)
    merge_status=$?

    if [ $merge_status -ne 0 ]; then
        log_message "Merge failed: $merge_output"
        handle_error "There was a conflict syncing templates. Please check the log for details."
        return $RC_ERROR
    fi

    log_message "Templates pull complete: $merge_output"
    log_message "(END TEMPLATES_PULL)"

    if echo "$merge_output" | grep -q "Already up to date"; then
        display_notification "Motion Templates" "Already up to date." ""
    else
        display_notification "Motion Templates" "Templates synced successfully." ""
    fi
    return $RC_SUCCESS
}

# Commit and push local template changes to the server
templates_push() {
    log_message "(BEGIN TEMPLATES_PUSH)"

    if ! templates_is_initialized; then
        handle_error "Motion Templates sync is not set up yet. Use 'Enable Motion Templates' first."
        return $RC_ERROR
    fi

    if ! templates_check_connectivity; then
        handle_error "Unable to connect to the server. Please check your connection and try again."
        return $RC_ERROR
    fi

    # Regenerate .gitignore to make sure it reflects current .sync-include
    generate_templates_gitignore

    # Stage config files (force-add to bypass the catch-all *)
    templates_git add -f "$TEMPLATES_SYNC_INCLUDE" "$TEMPLATES_GITIGNORE" 2>/dev/null

    # Force-add each tracked folder (they're excluded by the catch-all *)
    if [ -f "$TEMPLATES_SYNC_INCLUDE" ]; then
        while IFS= read -r folder; do
            [[ -z "$folder" || "$folder" == \#* ]] && continue
            folder_path="$TEMPLATES_WORK_TREE/$folder"
            if [ -d "$folder_path" ]; then
                show_details "Staging $folder..."
                templates_git add -f "$folder_path" 2>/dev/null
            fi
        done < "$TEMPLATES_SYNC_INCLUDE"
    fi

    # Check whether there is anything new to commit
    if templates_git diff-index --quiet HEAD -- 2>/dev/null && [ -z "$(templates_git status --porcelain 2>/dev/null)" ]; then
        log_message "No template changes to push"
        display_notification "Motion Templates" "No changes to push." ""
        return $RC_SUCCESS
    fi

    show_details "Committing template changes..."
    commit_output=$(templates_git commit -m "Template update by $CURRENT_USER on $(date +'%Y-%m-%d')" 2>&1)
    if [ $? -ne 0 ]; then
        log_message "Commit failed: $commit_output"
        handle_error "Failed to commit template changes."
        return $RC_ERROR
    fi

    show_details "Pushing to server..."
    push_output=$(templates_git push origin HEAD 2>&1)
    if [ $? -ne 0 ]; then
        log_message "Push failed: $push_output"
        handle_error "Failed to push template changes to server."
        return $RC_ERROR
    fi

    log_message "Templates pushed: $push_output"
    log_message "(END TEMPLATES_PUSH)"
    display_notification "Motion Templates" "Template changes pushed successfully." ""
    return $RC_SUCCESS
}

# Add a folder (given as a relative path within TEMPLATES_WORK_TREE) to the sync list,
# then commit and push.
# Parameters:
#   $1: rel_path — path relative to TEMPLATES_WORK_TREE (e.g. "Titles.localized/BrandLowerThird")
templates_add_folder() {
    local rel_path="$1"
    log_message "(BEGIN TEMPLATES_ADD_FOLDER: $rel_path)"

    if [ -z "$rel_path" ]; then
        log_message "Error: no path provided to templates_add_folder"
        return $RC_ERROR
    fi

    if ! templates_is_initialized; then
        handle_error "Motion Templates sync is not set up yet. Use 'Enable Motion Templates' first."
        return $RC_ERROR
    fi

    # Check for duplicate
    if [ -f "$TEMPLATES_SYNC_INCLUDE" ] && grep -qxF "$rel_path" "$TEMPLATES_SYNC_INCLUDE"; then
        log_message "Folder already in .sync-include: $rel_path"
        osascript -e "display dialog \"'$rel_path' is already being synced.\" buttons {\"OK\"} default button \"OK\"" &>/dev/null
        return $RC_SUCCESS
    fi

    if ! templates_check_connectivity; then
        handle_error "Unable to connect to the server. Please check your connection and try again."
        return $RC_ERROR
    fi

    # Add to .sync-include
    echo "$rel_path" >> "$TEMPLATES_SYNC_INCLUDE"

    # Regenerate .gitignore
    generate_templates_gitignore

    # Stage config files and the new folder (force-add to bypass catch-all *)
    templates_git add -f "$TEMPLATES_SYNC_INCLUDE" "$TEMPLATES_GITIGNORE" 2>/dev/null
    local folder_path="$TEMPLATES_WORK_TREE/$rel_path"
    if [ -d "$folder_path" ]; then
        show_details "Staging $rel_path..."
        templates_git add -f "$folder_path" 2>/dev/null
    fi

    show_details "Committing..."
    templates_git commit -m "Add template: $rel_path" 2>&1
    if [ $? -ne 0 ]; then
        handle_error "Failed to commit new template folder."
        return $RC_ERROR
    fi

    show_details "Pushing to server..."
    push_output=$(templates_git push origin HEAD 2>&1)
    if [ $? -ne 0 ]; then
        log_message "Push failed: $push_output"
        handle_error "Failed to push new template folder to server."
        return $RC_ERROR
    fi

    log_message "(END TEMPLATES_ADD_FOLDER)"
    display_notification "Motion Templates" "\"$rel_path\" added and pushed." ""
    return $RC_SUCCESS
}
