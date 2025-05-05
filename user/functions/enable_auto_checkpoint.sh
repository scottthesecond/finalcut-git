enable_auto_checkpoint() {
    # Define the command you want to schedule
    CRON_COMMAND="$SCRIPT_PATH checkpointall"

    # Define the cron schedule (every 15 minutes)
    CRON_SCHEDULE="*/15 * * * *"

    # Combine them into a single cron job entry
    CRON_JOB="$CRON_SCHEDULE $CRON_COMMAND"

    # Get current crontab content
    CURRENT_CRONTAB=$(crontab -l 2>/dev/null)

    # Check if the job already exists
    if echo "$CURRENT_CRONTAB" | grep -F "$CRON_COMMAND" >/dev/null 2>&1; then
        log_message "Autosave cron job already exists"
        return 0
    fi

    # Add the new job to the existing crontab
    if [ -z "$CURRENT_CRONTAB" ]; then
        echo "$CRON_JOB" | crontab -
    else
        echo "$CURRENT_CRONTAB
$CRON_JOB" | crontab -
    fi

    display_notification "Autosave Enabled" "UNFlab will autosave your work every 15 minutes."

    # Optional: Ensure the script is executable
    chmod +x "$SCRIPT_PATH"
}

