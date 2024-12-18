enable_auto_checkpoint() {

# Define the command you want to schedule
CRON_COMMAND="$SCRIPT_PATH checkpointall"

# Define the cron schedule (every 15 minutes)
CRON_SCHEDULE="*/15 * * * *"

# Combine them into a single cron job entry
CRON_JOB="$CRON_SCHEDULE $CRON_COMMAND"

# Check if the crontab already contains this job
(crontab -l 2>/dev/null | grep -F "$CRON_COMMAND") >/dev/null 2>&1 || {
    # If not found, append the new cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab - 2>/dev/null
    display_notification "Autosave Enabled" "UNFLab will autosave your work every 15 minutes."

}

# Optional: Ensure the script is executable
chmod +x "$SCRIPT_PATH"

}

