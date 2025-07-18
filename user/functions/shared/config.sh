# Load the .config file (for server and port if needed)
if [ -f "$CONFIG_FILE" ]; then
   set -a
   source "$CONFIG_FILE"
   set +a
   
   # FIX: Handle tilde expansion in SERVER_PATH
   # When the config file contains SERVER_PATH=~/repositories, bash expands the tilde
   # to the local home directory when sourcing. We need to convert it back to tilde
   # notation for remote server paths and fix the config file permanently.
   # Check if SERVER_PATH was expanded from a tilde (contains home directory)
   # This happens when the config file contains ~/something but gets expanded locally
   if [[ "$SERVER_PATH" == "$HOME"/* ]]; then
       # Convert back to tilde notation for remote server paths
       fixed_path=$(echo "$SERVER_PATH" | sed "s|^$HOME|~|")
       SERVER_PATH="$fixed_path"
       log_message "SERVER_PATH was expanded from tilde, converting back: '$SERVER_PATH'"
       
       # Fix the config file permanently by updating the SERVER_PATH line
       if [ -f "$CONFIG_FILE" ]; then
           # Create a backup of the original config file
           cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
           log_message "Created backup of config file before fixing tilde expansion"
           
           # Update the SERVER_PATH line in the config file
           if grep -q "^SERVER_PATH=" "$CONFIG_FILE"; then
               # Replace the existing SERVER_PATH line with the fixed version
               sed -i '' "s|^SERVER_PATH=.*|SERVER_PATH='$fixed_path'|" "$CONFIG_FILE"
               log_message "Fixed SERVER_PATH in config file: '$fixed_path'"
           else
               # Add the SERVER_PATH line if it doesn't exist
               echo "SERVER_PATH='$fixed_path'" >> "$CONFIG_FILE"
               log_message "Added SERVER_PATH to config file: '$fixed_path'"
           fi
       fi
   fi
   
   # Also handle the case where SERVER_PATH might be quoted in the config file
   # Remove surrounding quotes if they exist
   if [[ "$SERVER_PATH" =~ ^\".*\"$ ]]; then
       SERVER_PATH="${SERVER_PATH:1:-1}"
       log_message "Removed quotes from SERVER_PATH: '$SERVER_PATH'"
   fi
   
   # Handle the case where SERVER_PATH is empty or not set
   # Set a default value of ~/repositories
   if [ -z "$SERVER_PATH" ]; then
       SERVER_PATH="~/repositories"
       log_message "SERVER_PATH was empty, setting default: '$SERVER_PATH'"
       
       # Update the config file with the default value
       if [ -f "$CONFIG_FILE" ]; then
           if grep -q "^SERVER_PATH=" "$CONFIG_FILE"; then
               # Replace the existing SERVER_PATH line with the default
               sed -i '' "s|^SERVER_PATH=.*|SERVER_PATH='$SERVER_PATH'|" "$CONFIG_FILE"
               log_message "Updated empty SERVER_PATH in config file: '$SERVER_PATH'"
           else
               # Add the SERVER_PATH line if it doesn't exist
               echo "SERVER_PATH='$SERVER_PATH'" >> "$CONFIG_FILE"
               log_message "Added SERVER_PATH to config file: '$SERVER_PATH'"
           fi
       fi
   fi
   
   log_message "SERVER_PATH after config load: '$SERVER_PATH'"
else
    setup
fi