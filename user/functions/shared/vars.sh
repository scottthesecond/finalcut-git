#Variables
DATA_FOLDER="$HOME/fcp-git"
#REPO_FOLDER="$DATA_FOLDER/repos"
CHECKEDOUT_FOLDER="$DATA_FOLDER/checkedout"
CHECKEDIN_FOLDER="$DATA_FOLDER/.checkedin"
BACKUPS_FOLDER="$DATA_FOLDER/backups"
CONFIG_FILE="$DATA_FOLDER/.config"
LOGS_FOLDER="$DATA_FOLDER/logs"
LOG_FILE="$LOGS_FOLDER/fcpgit-$VERSION-$(date +'%Y-%m-%d').log"
selected_repo=""

CURRENT_USER=$(whoami)

# Return code constants
readonly RC_SUCCESS=0
readonly RC_ERROR=1
readonly RC_CANCEL=2

# Create logs folder if it doesn't exist
mkdir -p "$LOGS_FOLDER"

# Get the full path of the script
# Handle Platypus app bundling - the script is bundled in the main app
if [[ "$0" == *".app"* ]]; then
    # We're running from a Platypus app
    # Look for the bundled script in the main app bundle
    APP_BUNDLE_PATH=$(dirname "$0")
    
    # Try to find the main app bundle (the one containing the bundled script)
    # The child apps are nested inside the main app's Contents/Resources/
    if [[ "$APP_BUNDLE_PATH" == *"UNFlab Progress.app"* ]] || [[ "$APP_BUNDLE_PATH" == *"UNFlab Offload.app"* ]]; then
        # We're in a child app, need to find the main UNFlab.app
        # Navigate up the path until we find the main app
        CURRENT_PATH="$APP_BUNDLE_PATH"
        while [[ "$CURRENT_PATH" != "/" ]] && [[ "$CURRENT_PATH" != "" ]]; do
            # Look for the actual app bundle (ends with .app), not its contents
            if [[ "$CURRENT_PATH" == */UNFlab.app ]] && [[ "$CURRENT_PATH" != *"UNFlab Progress.app"* ]] && [[ "$CURRENT_PATH" != *"UNFlab Offload.app"* ]]; then
                # Found the main UNFlab.app
                MAIN_APP_PATH="$CURRENT_PATH"
                break
            fi
            CURRENT_PATH=$(dirname "$CURRENT_PATH")
        done
        
        # If we didn't find the main app, fall back to Applications
        if [ -z "$MAIN_APP_PATH" ] || [ "$MAIN_APP_PATH" = "/" ]; then
            MAIN_APP_PATH="/Applications/UNFlab.app"
        fi
        
        # For child apps, we know the main app's resources directory is always the same
        # Just set it directly to avoid path detection issues
        SCRIPT_DIR="$MAIN_APP_PATH/Contents/Resources"
        SCRIPT_PATH="$SCRIPT_DIR/script"
    else
        # We're in the main app
        MAIN_APP_PATH="$APP_BUNDLE_PATH"
        
        # For main app, use the standard path detection
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        SCRIPT_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
    fi
else
    # Running from command line or development
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SCRIPT_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
fi

# For running from the command line
BASH_SCRIPT_PATH="${SCRIPT_DIR}/fcp-git-user.sh"

echo "" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "[ $APP_NAME ($VERSION) START: $0 Args: $* ]" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
