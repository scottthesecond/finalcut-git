# Load the .config file (for server and port if needed)
if [ -f "$CONFIG_FILE" ]; then
   set -a
   source "$CONFIG_FILE"
   set +a
    log_message "SERVER_PATH after config load: '$SERVER_PATH'"
else
    setup
fi