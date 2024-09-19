# Load the .config file (for server and port if needed)
if [ -f "$CONFIG_FILE" ]; then
    export $(grep -v '^#' "$CONFIG_FILE" | xargs)
else
    setup
    # echo ".config file not found in $CONFIG_FILE!"
    # exit 1
fi