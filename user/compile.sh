#!/bin/bash

#Current directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
FUNCTIONS="$SCRIPT_DIR/functions"

# Define the array of script paths
scripts=(
    "$FUNCTIONS/vars.sh"
    "$FUNCTIONS/logs.sh"
    "$FUNCTIONS/setup.sh"
    "$FUNCTIONS/select_repo.sh"
    "$FUNCTIONS/checkin.sh"
    "$FUNCTIONS/checkout.sh"
    "$FUNCTIONS/config.sh"
    "$FUNCTIONS/dialogs.sh"
    "$FUNCTIONS/_main.sh"
)

# Define output file name
output_file="$SCRIPT_DIR/fcp-git-user.sh"

# Start fresh by creating the file and adding the shebang
echo "#!/bin/bash" > "$output_file"

# Loop through the array and concatenate each script
for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        echo "Concatenating $script into $output_file..."
        
        # Add a comment in the output file to indicate the start of a new script
        #echo -e "\n# --- Start of $script ---\n" >> "$output_file"
        
        # Append the content of the script to the output file
        cat "$script" >> "$output_file"
        
        # Add a comment to indicate the end of the script
        #echo -e "\n# --- End of $script ---\n" >> "$output_file"
    else
        echo "Warning: $script not found, skipping..."
    fi
done

# Make the combined script executable
chmod +x "$output_file"

echo "All scripts concatenated into $output_file"