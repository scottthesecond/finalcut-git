#!/bin/bash

#Current directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
FUNCTIONS="$SCRIPT_DIR/functions"
VERSION="3.0.0a8"
NAME="UNFlab"

# Default values
BUILD_WITH_PLATYPUS=false
SHOW_HELP=false
SKIP_BUILD=false

# Parse command line arguments
while [[ "$1" != "" ]]; do
    case $1 in
        --build|-b)
            BUILD_WITH_PLATYPUS=true
            ;;
        --no-build)
            SKIP_BUILD=true
            ;;
        --help|-h)
            SHOW_HELP=true
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Show help if requested
if [ "$SHOW_HELP" = true ]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --build, -b    Automatically build with Platypus without prompting"
    echo "  --no-build     Skip Platypus build entirely without prompting"
    echo "  --help, -h     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Build scripts and prompt for Platypus build"
    echo "  $0 --build      # Build scripts and automatically build with Platypus"
    echo "  $0 --no-build   # Build scripts only, skip Platypus build"
    echo "  $0 -b           # Same as --build"
    exit 0
fi

# Make build directory if it does not exist
mkdir -p "$SCRIPT_DIR/build"

#Clear out the build directory
rm -rf "$SCRIPT_DIR/build"/*

# Define the array of script paths
scripts=(
    "$FUNCTIONS/shared/vars.sh"
    "$FUNCTIONS/shared/logs.sh"
    "$FUNCTIONS/shared/setup.sh"
    "$FUNCTIONS/shared/select_repo.sh"
    "$FUNCTIONS/git/operations/checkConnectivity.sh"
    "$FUNCTIONS/git/operations/commitAndPush.sh"
    "$FUNCTIONS/git/operations/conflict.sh"
    "$FUNCTIONS/git/operations/checkedout.sh"
    "$FUNCTIONS/git/operations/lock.sh"
    "$FUNCTIONS/git/operations/repo_operations.sh"
    "$FUNCTIONS/git/operations/repo_utils.sh"
    "$FUNCTIONS/git/filesystem/checkOpenFiles.sh"
    "$FUNCTIONS/git/filesystem/checkRecentAccess.sh"
    "$FUNCTIONS/git/filesystem/move.sh"
    "$FUNCTIONS/git/checkin.sh"
    "$FUNCTIONS/git/checkpoint.sh"
    "$FUNCTIONS/git/checkpoint_all.sh"
    "$FUNCTIONS/git/checkout.sh"
    "$FUNCTIONS/git/operations/cleanup.sh"
    "$FUNCTIONS/git/cleanup_ui.sh"
    "$FUNCTIONS/shared/config.sh"
    "$FUNCTIONS/shared/dialogs.sh"
    "$FUNCTIONS/shared/fcp.sh"
    "$FUNCTIONS/git/enable_auto_checkpoint.sh"
    "$FUNCTIONS/offload/offload_utils.sh"
    "$FUNCTIONS/offload/offload.sh"
    "$FUNCTIONS/offload/offload_ui.sh"
    "$FUNCTIONS/offload/verify.sh"
    "$FUNCTIONS/shared/_main.sh"
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

# Check if we should build with Platypus
if [ "$SKIP_BUILD" = true ]; then
    echo "Skipping Platypus build as requested."
    build_with_platypus=false
elif [ "$BUILD_WITH_PLATYPUS" = true ]; then
    echo "Building with Platypus..."
    build_with_platypus=true
else
    # Ask the user if they want to continue
    read -p "Build app with Platypus?" choice
    
    # Check the user's input
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        build_with_platypus=true
    else
        build_with_platypus=false
    fi
fi

# Build with Platypus if requested
if [ "$build_with_platypus" = true ]; then
    echo "building..."

    OUT_ZIP="$SCRIPT_DIR/build/$NAME $VERSION.zip"
    OUT_APP="$NAME.app"
    APPLICATIONS_DIR="/Applications"

    # Check if any of the UNFlab apps are running and quit them
    progress_app_name="$NAME Progress"
    droplet_app_name="$NAME Offload"
    
    # Quit main UNFlab app
    if pgrep -f "$NAME.app" > /dev/null; then
        echo "Quitting existing $NAME application..."
        pkill -f "$NAME.app"
    fi
    
    # Quit progress bar app
    if pgrep -f "$progress_app_name.app" > /dev/null; then
        echo "Quitting existing $progress_app_name application..."
        pkill -f "$progress_app_name.app"
    fi
    
    # Quit droplet app
    if pgrep -f "$droplet_app_name.app" > /dev/null; then
        echo "Quitting existing $droplet_app_name application..."
        pkill -f "$droplet_app_name.app"
    fi
    
    # Give apps a moment to quit
    sleep 2

    # Remove existing app from Applications if it exists
    if [ -d "$APPLICATIONS_DIR/$OUT_APP" ]; then
        echo "Removing existing $NAME from Applications..."
        rm -rf "$APPLICATIONS_DIR/$OUT_APP"
    fi

    # Build the progress bar app with Platypus (using same script)
    echo "Building progress bar app..."
    progress_out_app="$progress_app_name.app"
    
    /usr/local/bin/platypus \
        --app-icon "$SCRIPT_DIR/app/AppIcon.icns"\
        --name "$progress_app_name"\
        --app-version "$VERSION"\
        --author "Unnamed Media"\
        --interface-type 'Progress Bar'\
        --interpreter '/bin/bash'\
        --script-args '-progressbar'\
        --bundled-file "$output_file"\
        "$SCRIPT_DIR/build/fcp-git-user.sh"\
        "$SCRIPT_DIR/build/$progress_out_app"
    
    # Build the offload droplet app with Platypus
    echo "Building offload droplet app..."
    droplet_out_app="$droplet_app_name.app"
    
    /usr/local/bin/platypus \
        --app-icon "$SCRIPT_DIR/app/AppIcon.icns"\
        --name "$droplet_app_name"\
        --app-version "$VERSION"\
        --author "Unnamed Media"\
        --interface-type 'Droplet'\
        --interpreter '/bin/bash'\
        --script-args '-droplet'\
        --droppable \
        --uniform-type-identifiers 'public.folder|public.item'\
        --bundled-file "$output_file"\
        "$SCRIPT_DIR/build/fcp-git-user.sh"\
        "$SCRIPT_DIR/build/$droplet_out_app"
    
    # Build the status menu app with Platypus (including progress app and droplet as bundled files)
    echo "Building status menu app with bundled progress app and droplet..."
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
        --bundled-file "$SCRIPT_DIR/build/$progress_out_app"\
        --bundled-file "$SCRIPT_DIR/build/$droplet_out_app"\
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
