#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1) Check if Git is installed
if command_exists git; then
    echo "Git is already installed."
else
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
    # echo "No SSH public key found. Generating a new SSH key."
    echo "I am going to generate a public key to allow you to access the GIT server.  Just a moment..."
    read -p "Enter your email address: " email
    ssh-keygen -t ed25519 -C "$email"
    SSH_KEY_PUB="$SSH_DIR/id_ed25519.pub"
fi

# Return the SSH public key
echo -e "\nYour public key is below.  Please copy the whole thing and give it to your manager:\n"
cat "$SSH_KEY_PUB"