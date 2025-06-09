
moveToHiddenCheckinFolder(){
    log_message "moving repo to .checkedin folder..."
    mv "$CHECKEDOUT_FOLDER/$selected_repo" "$CHECKEDIN_FOLDER/$selected_repo" || handle_error "Couldn't move $selected_repo to the checkedin folder – make sure you've closed all projects."

    log_message "Setting repository $selected_repo to read-only"
    chmod -R u-w "$CHECKEDIN_FOLDER/$selected_repo" || handle_error "Failed to set repository $selected_repo to read-only"
    log_message "Repository $selected_repo is now read-only"

}

move_to_checkedout(){
    mv "$CHECKEDIN_FOLDER/$selected_repo" "$CHECKEDOUT_FOLDER/$selected_repo"
}
