#!/bin/bash

#Current directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
FUNCTIONS="$SCRIPT_DIR/functions"
VERSION="2.2"
NAME="UNFlab"

# Make build directory if it does not exist
mkdir -p "$SCRIPT_DIR/build"

#Clear out the build directory
rm -rf "$SCRIPT_DIR/build"/*

# Define the array of script paths
scripts=(
    "$FUNCTIONS/vars.sh"
    "$FUNCTIONS/logs.sh"
    "$FUNCTIONS/setup.sh"
    "$FUNCTIONS/select_repo.sh"
    "$FUNCTIONS/GIT Operations/checkConnectivity.sh"
    "$FUNCTIONS/GIT Operations/commitAndPush.sh"
    "$FUNCTIONS/GIT Operations/conflict.sh"
    "$FUNCTIONS/GIT Operations/checkedout.sh"
    "$FUNCTIONS/GIT Operations/lock.sh"
    "$FUNCTIONS/GIT Operations/repo_operations.sh"
    "$FUNCTIONS/Filesystem Operations/checkOpenFiles.sh"
    "$FUNCTIONS/Filesystem Operations/checkRecentAccess.sh"
    "$FUNCTIONS/Filesystem Operations/move.sh"
    "$FUNCTIONS/checkin.sh"
    "$FUNCTIONS/checkpoint.sh"
    "$FUNCTIONS/checkpoint_all.sh"
    "$FUNCTIONS/checkout.sh"
    "$FUNCTIONS/config.sh"
    "$FUNCTIONS/dialogs.sh"
    "$FUNCTIONS/fcp.sh"
    "$FUNCTIONS/enable_auto_checkpoint.sh"
    "$FUNCTIONS/_main.sh"
)

# Define output file name
output_file="$SCRIPT_DIR/build/fcp-git-user.sh"
#autosave_copy="$SCRIPT_DIR/build/fcp-git-user.sh"

# Start fresh by creating the file and adding the shebang
echo "#!/bin/bash" > "$output_file"

echo "VERSION=$VERSION" >> "$output_file"
echo "APP_NAME=$NAME" >> "$output_file"


# Loop through the array and concatenate each script
for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        echo "Concatenating $script into $output_file..."
        cat "$script" >> "$output_file"
        echo "" >> "$output_file"
    else
        echo "Warning: $script not found, skipping..."
    fi
done

#cp "$output_file" "$autosave_copy"

# Make the combined script executable
chmod +x "$output_file"
#chmod +x "$autosave_copy"
echo "All scripts concatenated into $output_file."

# Ask the user if they want to continue
read -p "Build app with Platypus?" choice

# Check the user's input
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    echo "building..."

    OUT_ZIP="$SCRIPT_DIR/build/$NAME $VERSION.zip"
    OUT_APP="$NAME.app"
    APPLICATIONS_DIR="/Applications"

    # Check if the app is running and quit it
    if pgrep -f "$NAME.app" > /dev/null; then
        echo "Quitting existing $NAME application..."
        pkill -f "$NAME.app"
        # Give it a moment to quit
        sleep 2
    fi

    # Remove existing app from Applications if it exists
    if [ -d "$APPLICATIONS_DIR/$OUT_APP" ]; then
        echo "Removing existing $NAME from Applications..."
        rm -rf "$APPLICATIONS_DIR/$OUT_APP"
    fi

    # Build the app with Platypus
    /usr/local/bin/platypus \
        --app-icon "$SCRIPT_DIR/app/AppIcon.icns"\
        --background \
        --name "$NAME"\
        --app-version "$VERSION"\
        --author "Unnamed Media"\
        --interface-type 'Status Menu'\
        --interpreter '/bin/bash'\
        --script-args '-navbar'\
        --status-item-kind 'Text'\
        --status-item-title "$NAME"\
        --uri-schemes 'fcpgit'\
        --status-item-sysfont\
        --status-item-template-icon\
        --uniform-type-identifiers 'public.item|public.folder'\
        --bundled-file "$output_file"\
        "$SCRIPT_DIR/build/fcp-git-user.sh"\
        "$SCRIPT_DIR/build/$OUT_APP"
  
    cd "$SCRIPT_DIR/build"
    zip -r "$OUT_ZIP" "$OUT_APP"

    # Copy the new app to Applications
    echo "Copying $NAME to Applications..."
    cp -R "$OUT_APP" "$APPLICATIONS_DIR/"

    # Launch the new app
    echo "Launching $NAME..."
    open "$APPLICATIONS_DIR/$OUT_APP"

    echo "done."

    # open "$SCRIPT_DIR/build/$OUT_APP"
fi
