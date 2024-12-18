#!/bin/bash

#Variables
DATA_FOLDER="$HOME/fcp-git"
#REPO_FOLDER="$DATA_FOLDER/repos"
CHECKEDOUT_FOLDER="$DATA_FOLDER/checkedout"
CHECKEDIN_FOLDER="$DATA_FOLDER/.checkedin"
CONFIG_FILE="$DATA_FOLDER/.config"
LOG_FILE="$DATA_FOLDER/fcp-git.log"
selected_repo=""

# Get the full path of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"

