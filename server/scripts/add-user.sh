#!/bin/bash

# Check if ~/.ssh directory exists, if not, create it
if [ ! -d "$HOME/.ssh" ]; then
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
fi

# Prompt the user to paste the public key
echo "Please paste the public key and press Enter, followed by Ctrl+D:"

# Read the public key input
pub_key=$(cat)

# Add the public key to ~/.ssh/authorized_keys if it's not already there
if grep -q "$pub_key" "$HOME/.ssh/authorized_keys"; then
  echo "The key is already present in ~/.ssh/authorized_keys."
else
  echo "$pub_key" >> "$HOME/.ssh/authorized_keys"
  chmod 600 "$HOME/.ssh/authorized_keys"
  echo "Public key added to ~/.ssh/authorized_keys."
fi