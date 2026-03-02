# Motion Templates sync — menu and UI

# Output the Motion Templates SUBMENU string for the Platypus status menu
display_templates_submenu() {
    local items=""

    if templates_is_initialized; then
        items="Pull Templates|Push Template Changes|Add Template Folder...|----"

        local synced
        synced="$(templates_list_synced)"
        if [ -n "$synced" ]; then
            items="$items|DISABLED|Synced folders:"
            while IFS= read -r folder; do
                items="$items|DISABLED|  $folder"
            done <<< "$synced"
        else
            items="$items|DISABLED|No folders synced yet"
        fi
    else
        items="Enable Motion Templates|DISABLED|Motion Templates not configured"
    fi

    echo "SUBMENU|Motion Templates|$items"
}

# AppleScript folder picker: user selects a folder inside the Motion Templates directory.
# Calls templates_add_folder() with the relative path.
templates_add_folder_ui() {
    log_message "(BEGIN TEMPLATES_ADD_FOLDER_UI)"

    local work_tree="$TEMPLATES_WORK_TREE"

    # Show folder picker starting at the Motion Templates directory.
    # 'choose folder' is a Standard Additions command — must NOT be inside
    # a 'tell application' block or it fails silently on some macOS versions.
    local picked
    picked=$(osascript <<EOF
set chosenFolder to choose folder with prompt "Select a template folder to sync:" default location POSIX file "$work_tree"
POSIX path of chosenFolder
EOF
)
    local osascript_status=$?

    if [ $osascript_status -ne 0 ] || [ -z "$picked" ]; then
        log_message "User cancelled folder picker"
        return $RC_SUCCESS
    fi

    log_message "User picked: $picked"

    # Strip trailing slash
    picked="${picked%/}"

    # Normalise the work tree path for comparison (strip trailing slash)
    local wt_norm="${work_tree%/}"

    # Validate selection is inside the Motion Templates folder
    if [[ "$picked" != "$wt_norm/"* ]]; then
        osascript -e "display dialog \"Please select a folder inside your Motion Templates folder:\n$work_tree\" buttons {\"OK\"} default button \"OK\"" &>/dev/null
        log_message "Selection outside Motion Templates folder: $picked"
        return $RC_ERROR
    fi

    # Derive relative path
    local rel_path="${picked#$wt_norm/}"
    log_message "Relative path: $rel_path"

    if [ -z "$rel_path" ]; then
        osascript -e "display dialog \"Please select a specific template folder, not the Motion Templates folder itself.\" buttons {\"OK\"} default button \"OK\"" &>/dev/null
        return $RC_ERROR
    fi

    templates_add_folder "$rel_path"
    log_message "(END TEMPLATES_ADD_FOLDER_UI)"
}

# Dispatch templates menu actions
# Parameters:
#   $1: action — one of: enable, sync, push, add_folder
handle_templates_menu() {
    local action="$1"
    log_message "handle_templates_menu: $action"

    case "$action" in
        "enable")
            templates_init
            ;;
        "sync")
            templates_pull
            ;;
        "push")
            templates_push
            ;;
        "add_folder")
            templates_add_folder_ui
            ;;
        *)
            handle_error "Unknown templates action: $action"
            ;;
    esac
}
