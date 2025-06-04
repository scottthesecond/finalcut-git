

#Variables
DATA_FOLDER="$HOME/fcp-git"
#REPO_FOLDER="$DATA_FOLDER/repos"
CHECKEDOUT_FOLDER="$DATA_FOLDER/checkedout"
CHECKEDIN_FOLDER="$DATA_FOLDER/.checkedin"
CONFIG_FILE="$DATA_FOLDER/.config"
LOGS_FOLDER="$DATA_FOLDER/logs"
LOG_FILE="$LOGS_FOLDER/fcpgit-$VERSION-$(date +'%Y-%m-%d').log"
selected_repo=""

# Create logs folder if it doesn't exist
mkdir -p "$LOGS_FOLDER"

# Get the full path of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"

# For running from the command line
BASH_SCRIPT_PATH="${SCRIPT_DIR}/fcp-git-user.sh"

echo "" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
echo "[ $APP_NAME ($VERSION) START: $0 Args: $* ]" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
