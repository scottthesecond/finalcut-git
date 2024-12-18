#!/bin/bash

#Current directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
FUNCTIONS="$SCRIPT_DIR/functions"
VERSION="2.0.5"
NAME="UNFlab"

# Define the array of script paths
scripts=(
    "$FUNCTIONS/vars.sh"
    "$FUNCTIONS/logs.sh"
    "$FUNCTIONS/setup.sh"
    "$FUNCTIONS/select_repo.sh"
    "$FUNCTIONS/checkin.sh"
    "$FUNCTIONS/checkpoint.sh"
    "$FUNCTIONS/checkout.sh"
    "$FUNCTIONS/config.sh"
    "$FUNCTIONS/dialogs.sh"
    "$FUNCTIONS/fcp.sh"
    "$FUNCTIONS/enable_auto_checkpoint.sh"
    "$FUNCTIONS/_main.sh"
)

# Define output file name
output_file="$SCRIPT_DIR/fcp-git-user.sh"

# Start fresh by creating the file and adding the shebang
echo "#!/bin/bash" > "$output_file"

echo "VERSION=$VERSION" >> "$output_file"
echo "APP_NAME=$NAME" >> "$output_file"


# Loop through the array and concatenate each script
for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        echo "Concatenating $script into $output_file..."
        cat "$script" >> "$output_file"
        echo -e "\n" >> "$output_file"
    else
        echo "Warning: $script not found, skipping..."
    fi
done

# Make the combined script executable
chmod +x "$output_file"

echo "All scripts concatenated into $output_file."

# Ask the user if they want to continue
read -p "Build app with Platypus?" choice

# Check the user's input
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    echo "building..."
    mkdir -p "$SCRIPT_DIR/build"

    OUT_ZIP="$SCRIPT_DIR/build/$NAME $VERSION.zip"
    OUT_APP="$NAME.app"
    #OUT_SB_APP="$NAME-statusbar.app"

    #/usr/local/bin/platypus --app-icon "$SCRIPT_DIR/app/AppIcon.icns"  --name "$NAME" --app-version "$VERSION" --author "Unnamed Media" --interface-type 'None'  --interpreter '/bin/bash'  --uniform-type-identifiers 'public.item|public.folder' --uri-schemes 'fcpgit' --quit-after-execution "$SCRIPT_DIR/fcp-git-user.sh" "$SCRIPT_DIR/build/$OUT_APP"
    /usr/local/bin/platypus --app-icon "$SCRIPT_DIR/app/AppIcon.icns"  --background --name "$NAME" --app-version "$VERSION" --author "Unnamed Media" --interface-type 'Status Menu'  --interpreter '/bin/bash'  --script-args '-navbar' --status-item-kind 'Text' --status-item-title 'UNFLab' --uri-schemes 'fcpgit' --status-item-sysfont --status-item-template-icon --uniform-type-identifiers 'public.item|public.folder'  "$SCRIPT_DIR/fcp-git-user.sh" "$SCRIPT_DIR/build/$OUT_APP"
  
    cd "$SCRIPT_DIR/build"
    zip -r "$OUT_ZIP" "$OUT_APP"

    echo "done."
fi
