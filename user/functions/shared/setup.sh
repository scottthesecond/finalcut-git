command_exists() {
    command -v "$1" >/dev/null 2>&1
}

setup() {
	CONFIRM=$(osascript -e 'display dialog "Set up UNFlab?" buttons {"Yes", "No"} default button "Yes"' -e 'button returned of result')
	if [ "$CONFIRM" == "No" ]; then
		exit
	fi

	# Use setup_ui functions to prompt for configuration
	prompt_server_address
	prompt_server_port
	prompt_server_path

	# Create Folders
	mkdir -p "$DATA_FOLDER"
	mkdir -p "$CHECKEDOUT_FOLDER"
	mkdir -p "$CHECKEDIN_FOLDER"


	# 1) Check if Git is installed
	if command_exists git; then
		log_message "Git is already installed"
	else
		log_message "Git is not installed."
		echo "Git is not installed. Press enter to install the Xcode Command Line Tools, which will install GIT."
		echo "For all your options to install GIT, go to https://git-scm.com/download/mac."
		read -r
		xcode-select --install
		echo "Please follow the prompts to install Xcode Command Line Tools."
		echo "Press Enter once the installation is complete."
		read -r
	fi

	# 2) Check if the user has an SSH public key
	SSH_DIR="$HOME/.ssh"
	SSH_KEY_PUB=""

	if [ -f "$SSH_DIR/id_ed25519.pub" ]; then
		SSH_KEY_PUB="$SSH_DIR/id_ed25519.pub"
	elif [ -f "$SSH_DIR/id_rsa.pub" ]; then
		SSH_KEY_PUB="$SSH_DIR/id_rsa.pub"
	else
		# Generate the SSH Key
		log_message "No SSH public key found. Generating a new SSH key."
		# echo "No SSH public key found. Generating a new SSH key."
		#read -p "Enter your email address: " email
		email=$(osascript -e 'display dialog "I am going to generate a public key to allow you to access the GIT server.  Please enter your email:" default answer ""' -e 'text returned of result')
		ssh-keygen -t ed25519 -C "$email" -q -N "" -f "$HOME/.ssh/id_ed25519"
		SSH_KEY_PUB="$SSH_DIR/id_ed25519.pub"
		
		# Check if key generation was successful
		if [ ! -f "$SSH_KEY_PUB" ]; then
			log_message "Failed to generate SSH key"
			handle_error "Failed to generate SSH key. Please try again."
			return 1
		fi
	fi

	# Display the SSH public key
	echo "Your SSH public key:"
	cat "$SSH_KEY_PUB"
	osascript -e "display dialog \"Your public key is below. Please copy the whole thing and give it to your manager:\" default answer \"$(cat "$SSH_KEY_PUB")\"" -e 'text returned of result'
}