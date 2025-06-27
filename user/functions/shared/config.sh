# Load the .config file (for server and port if needed)
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    log_message "SERVER_PATH after config load: '$SERVER_PATH'"
else
    setup
fi