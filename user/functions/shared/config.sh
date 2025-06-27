# Load the .config file (for server and port if needed)
if [ -f "$CONFIG_FILE" ]; then
   # source "$CONFIG_FILE"
   export $(grep -v '^#' "$CONFIG_FILE" | xargs)
    log_message "SERVER_PATH after config load: '$SERVER_PATH'"
else
    setup
fi