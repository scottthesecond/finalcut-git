echo "Setting up FCP-GIT!"


# Define the target folder path
TARGET_FOLDER="$HOME/fcp-git"
REPO_FOLDER="$TARGET_FOLDER/repos"

# Create t# Get the full path of the script directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Define the path to the parent directory where checkout.sh is located
PARENT_DIR=$(dirname "$SCRIPT_DIR")

mkdir -p "$TARGET_FOLDER"
mkdir -p "$REPO_FOLDER"
echo "Created folder at: $TARGET_FOLDER"

# Define the .env file path
ENV_FILE="$TARGET_FOLDER/.env"

# Ask the user for server address and port
read -p "Enter server address: " SERVER_ADDRESS
read -p "Enter server port: " SERVER_PORT

# Write the server address and port to the .env file
echo "SERVER_ADDRESS=$SERVER_ADDRESS" > "$ENV_FILE"
echo "SERVER_PORT=$SERVER_PORT" >> "$ENV_FILE"
echo "Saved server information to $ENV_FILE"

# Copy checkout.sh and checkin.sh to the fcp-git folder
cp "$PARENT_DIR/checkout.sh" "$TARGET_FOLDER/"
chmod +x "$TARGET_FOLDER/checkout.sh"
cp "$PARENT_DIR/checkin.sh" "$TARGET_FOLDER/"
chmod +x "$TARGET_FOLDER/checkin.sh"

#cp ../checkin.sh "$TARGET_FOLDER/"
echo "Copied checkout.sh and checkin.sh to $TARGET_FOLDER"

# Get the directory where the current script is located
SCRIPT_DIR=$(dirname "$0")

# Run a script located in the same folder as this script
bash "$SCRIPT_DIR/git-ssh-setup.sh"

