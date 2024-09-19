#!/bin/bash

# --- Start of /Users/shoek/Git Testing/finalcut-git/user/functions/vars.sh ---

#!/bin/bash

#Variables
DATA_FOLDER="$HOME/fcp-git"
REPO_FOLDER="$DATA_FOLDER/repos"
CONFIG_FILE="$DATA_FOLDER/.config"
LOG_FILE="$DATA_FOLDER/fcp-git.log"
selected_repo=""
# --- End of /Users/shoek/Git Testing/finalcut-git/user/functions/vars.sh ---


# --- Start of /Users/shoek/Git Testing/finalcut-git/user/functions/logs.sh ---

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to handle errors
handle_error() {
    echo "$1"
    log_message "ERROR: $1"
    osascript -e "display dialog \"Error: $1.  See log for details.\" buttons {\"OK\"} default button \"OK\""
    exit 1
}
# --- End of /Users/shoek/Git Testing/finalcut-git/user/functions/logs.sh ---


# --- Start of /Users/shoek/Git Testing/finalcut-git/user/functions/setup.sh ---

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

setup() {
	CONFIRM=$(osascript -e 'display dialog "Set up UNFlab?" buttons {"Yes", "No"} default button "Yes"' -e 'button returned of result')
	if [ "$CONFIRM" == "No" ]; then
		exit
	fi

	SERVER_ADDRESS=$(osascript -e 'display dialog "Enter server address:" default answer ""' -e 'text returned of result')
	SERVER_PORT=$(osascript -e 'display dialog "Enter server port:" default answer "22"' -e 'text returned of result')
	SERVER_PATH=$(osascript -e 'display dialog "Enter server path:" default answer "~/repositories"' -e 'text returned of result')

	#Create Folders
	mkdir -p "$DATA_FOLDER"
	mkdir -p "$REPO_FOLDER"

	# Write the server address and port to the .env file
	echo "SERVER_ADDRESS=$SERVER_ADDRESS" > "$CONFIG_FILE"
	echo "SERVER_PORT=$SERVER_PORT" >> "$CONFIG_FILE"
	echo "SERVER_PATH=$SERVER_PATH" >> "$CONFIG_FILE"

	# 1) Check if Git is installed
	if command_exists git; then
		log_message "Git is already installed"
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

}
# --- End of /Users/shoek/Git Testing/finalcut-git/user/functions/setup.sh ---


# --- Start of /Users/shoek/Git Testing/finalcut-git/user/functions/select_repo.sh ---

# Function to select a repo using AppleScript
select_repo() {
    # Default is false, i.e., no "New" option
    local enable_new="false"

    # Check if --allowNew flag is passed
    for arg in "$@"; do
        if [ "$arg" == "--allowNew" ]; then
            enable_new="true"
            break
        fi
    done

    # List all folders inside the repos directory
    folders=("$REPO_FOLDER"/*)
    
    # Check if there are any repositories
    if [ ${#folders[@]} -eq 0 ]; then
        osascript -e 'display dialog "No repositories found in the repos folder." buttons {"OK"} default button "OK"'
        exit 1
    fi

    # Create an AppleScript list with repo names
    repo_list=""
    for i in "${!folders[@]}"; do
        folder_name=$(basename "${folders[$i]}")
        repo_list="$repo_list\"$folder_name\", "
    done

    # If "New" option is enabled, add it to the list
    if [ "$enable_new" == "true" ]; then
        repo_list="$repo_list\"New\""
    else
        # Remove the trailing comma and space if "New" is not added
        repo_list="${repo_list%, }"
    fi

    # Use AppleScript to display a dialog with the repo options
    selected_repo=$(osascript -e "choose from list {$repo_list} with prompt \"Select an existing repository:\"")

    # Check if the user selected "New" (only if enabled)
    if [ "$selected_repo" == "false" ]; then
        # User pressed cancel
        exit 0
    elif [ "$enable_new" == "true" ] && [ "$selected_repo" == "New" ]; then
        # Ask the user to input a new repository name
        selected_repo=$(osascript -e 'display dialog "Enter the name of the new repository:" default answer ""' -e 'text returned of result')

        # Create the new repository folder
        #mkdir -p "$REPO_FOLDER/$selected_repo"
    fi

    # Navigate to the selected or newly created repository
    cd "$REPO_FOLDER/$selected_repo" || osascript -e 'display dialog "Failed to navigate to the selected repository." buttons {"OK"} default button "OK"'
}
# --- End of /Users/shoek/Git Testing/finalcut-git/user/functions/select_repo.sh ---


# --- Start of /Users/shoek/Git Testing/finalcut-git/user/functions/checkin.sh ---

#!/bin/bash

checkin() {

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from checkout script: $selected_repo"
        cd "$REPO_FOLDER/$selected_repo" || handle_error "Failed to navigate to $selected_repo"
    else
        select_repo
    fi

    # Get the current date and the user's name
    current_date=$(date +"%Y-%m-%d")
    user_name=$(whoami)

    # Stage all changes, commit with the current date and username, and push
    log_message "Staging changes in $selected_repo"
    rm "$REPO_FOLDER/$selected_repo/CHECKEDOUT" 
    git add . >> "$LOG_FILE" 2>&1 || handle_error "Failed to stage changes in $selected_repo"
    log_message "Committing changes in $selected_repo"
    git commit -m "Commit on $current_date by $user_name" >> "$LOG_FILE" 2>&1 || handle_error "Git commit failed in $selected_repo"
    log_message "Pushing changes for $selected_repo"
    git push >> "$LOG_FILE" 2>&1 || handle_error "Git push failed for $selected_repo"

    log_message "Changes have been successfully checked in and pushed for $selected_repo."
    echo "Changes have been checked in and pushed for $selected_repo."

    # Set the repository to read-only
    log_message "Setting repository $selected_repo to read-only"
    chmod -R u-w "$REPO_FOLDER/$selected_repo" || handle_error "Failed to set repository $selected_repo to read-only"
    log_message "Repository $selected_repo is now read-only"
    echo "Repository $selected_repo is now read-only."
}


# --- End of /Users/shoek/Git Testing/finalcut-git/user/functions/checkin.sh ---


# --- Start of /Users/shoek/Git Testing/finalcut-git/user/functions/checkout.sh ---


checkout() {
    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
    else
        select_repo --allowNew
    fi

    # Check if the repository exists locally
    if [ ! -d "$REPO_FOLDER/$selected_repo" ]; then
        log_message "Repository $selected_repo does not exist locally. Cloning..."
        git clone "$REMOTE_SERVER/$selected_repo.git" "$REPO_FOLDER/$selected_repo" >> "$LOG_FILE" 2>&1 || handle_error "Git clone failed for $selected_repo"
        log_message "Repository cloned: $selected_repo"
        osascript -e "display dialog \"New repository cloned: $selected_repo\" buttons {\"OK\"} default button \"OK\""

    else
        log_message "Selected existing repository: $selected_repo"
    fi
    
    log_message "Making repository $selected_repo writable"
    chmod -R u+w "$REPO_FOLDER/$selected_repo" || handle_error "Failed to make repository $selected_repo writable"

    log_message "Repository $selected_repo is now writable"
    
    echo "Repository $selected_repo is now writable."
    cd "$REPO_FOLDER/$selected_repo" || handle_error "Failed to navigate to $selected_repo"

    log_message "Running git pull in $selected_repo"
    git pull >> "$LOG_FILE" 2>&1 || handle_error "Git pull failed for $selected_repo"

    # Navigate to the selected repository
    cd "$REPO_FOLDER/$selected_repo" || handle_error "Failed to navigate to $selected_repo"

    # Get the current user
    CURRENT_USER=$(whoami)

    # Check if the repository is already checked out
    if [ -f "$REPO_FOLDER/$selected_repo/CHECKEDOUT" ]; then
        checked_out_by=$(cat "$REPO_FOLDER/$selected_repo/CHECKEDOUT")
        if [ "$checked_out_by" != "$CURRENT_USER" ]; then
            chmod -R u-w "$REPO_FOLDER/$selected_repo"
            log_message "Repository is already checked out by $checked_out_by"
            osascript -e "display dialog \"Repository is already checked out by $checked_out_by.\" buttons {\"OK\"} default button \"OK\""
            exit 1
        fi
    else
        # Create the CHECKEDOUT file with the current user
        echo "$CURRENT_USER" > "$REPO_FOLDER/$selected_repo/CHECKEDOUT"
        git add "$REPO_FOLDER/$selected_repo/CHECKEDOUT" >> "$LOG_FILE" 2>&1 || handle_error "Failed to add CHECKEDOUT file."
        git commit -m "Checked out by $CURRENT_USER" >> "$LOG_FILE" 2>&1 || handle_error "Failed to commit CHECKEDOUT file."
        git push >> "$LOG_FILE" 2>&1 || handle_error "Failed to push CHECKEDOUT file."
        log_message "Repository checked out by $CURRENT_USER"
    fi

    # Open the repository directory
    open "$REPO_FOLDER/$selected_repo"

    # Use AppleScript to inform the user
    osascript -e "display dialog \"You are now checked out into $selected_repo.  Press OK when you are done making changes, and the changes will be checked in.\" buttons {\"OK\"} default button \"OK\""

    checkin "$selected_repo"

}

# checkout(){

#     # Function to display the menu and allow the user to select or enter a new repo
#     select_repo() {
#         echo "Select an existing repository or enter the name of a new one:"
#         echo "-----------------------------------------------------------"

#         # List all folders inside the repos directory
#         folders=("$REPO_DIR"/*)
#         if [ ${#folders[@]} -eq 0 ]; then
#             echo "No repositories found in $REPO_DIR"
#         else
#             for i in "${!folders[@]}"; do
#                 folder_name=$(basename "${folders[$i]}")
#                 echo "$((i+1))) $folder_name"
#             done
#         fi

#         # Prompt user for selection or new entry
#         echo "N) Enter the name of a new repository"
#         echo ""
#         read -p "Enter your choice [1-${#folders[@]} or N for new]: " choice

#         # Handle user input
#         if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#folders[@]}" ]; then
#             selected_repo=$(basename "${folders[$((choice-1))]}")
#             log_message "Selected existing repository: $selected_repo"
#             # Make the repository writable again
#             log_message "Making repository $selected_repo writable"
#             log_message "Repository $selected_repo is now writable"
#             echo "Repository $selected_repo is now writable."
#             cd "$REPO_DIR/$selected_repo" || handle_error "Failed to navigate to $selected_repo"
#             log_message "Running git pull in $selected_repo"
#             git pull >> "$LOG_FILE" 2>&1 || handle_error "Git pull failed for $selected_repo"
#         elif [[ "$choice" =~ ^[Nn]$ ]]; then
#             read -p "Enter the name of the new repository: " new_repo
#             log_message "Cloning new repository: $new_repo"
#             git clone "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$new_repo.git" "$REPO_DIR/$new_repo" >> "$LOG_FILE" 2>&1 || handle_error "Git clone failed for $new_repo"
#             log_message "New repository cloned: $new_repo"

#             # Navigate into the new repository directory
#             selected_repo="$new_repo"
#             cd "$REPO_DIR/$selected_repo" || handle_error "Failed to navigate to $selected_repo"
#         else
#             echo "Invalid option. Please try again."
#             select_repo
#         fi
        
#         # Function to get the current username
#         CURRENT_USER=$(whoami)
        
#         # Check if the CHECKEDOUT file exists
#         if [ ! -f "$REPO_DIR/$selected_repo/CHECKEDOUT" ]; then
#             # If CHECKEDOUT does not exist, create it
#             echo "$CURRENT_USER" > "$REPO_DIR/$selected_repo/CHECKEDOUT"
#             git add "$REPO_DIR/$selected_repo/CHECKEDOUT" >> "$LOG_FILE" 2>&1 || handle_error "failed to check out."
#             git commit -m "Checked out by $CURRENT_USER" >> "$LOG_FILE" 2>&1 || handle_error "failed to check out."
#             git push >> "$LOG_FILE" 2>&1 || handle_error "failed to check out."
#             open "$REPO_DIR/$new_repo"
#         else
#             checked_out_by=$(cat "$REPO_DIR/$selected_repo/CHECKEDOUT")
            
#             if [ "$checked_out_by" != "$CURRENT_USER" ]; then
#                 chmod -R u-w "$REPO_DIR/$selected_repo"
#                 log_message "Repository is already checked out by $checked_out_by"
#                 echo "Repository is already checked out by $checked_out_by."
#                 exit 1
#             fi
#         fi
#     }

#     # Run the function to display the selection menu
#     select_repo



#     # Inform the user and wait for them to press Enter
#     echo "You are now checked out into $selected_repo."



#     read -p "Press Enter when you are done making changes, and the changes will be checked in."



#     # Automatically call the checkin.sh script to commit and push changes
#     "$HOME/fcp-git/checkin.sh" "$selected_repo"


# }
# --- End of /Users/shoek/Git Testing/finalcut-git/user/functions/checkout.sh ---


# --- Start of /Users/shoek/Git Testing/finalcut-git/user/functions/config.sh ---

# Load the .config file (for server and port if needed)
if [ -f "$CONFIG_FILE" ]; then
    export $(grep -v '^#' "$CONFIG_FILE" | xargs)
else
    setup
    # echo ".config file not found in $CONFIG_FILE!"
    # exit 1
fi
# --- End of /Users/shoek/Git Testing/finalcut-git/user/functions/config.sh ---


# --- Start of /Users/shoek/Git Testing/finalcut-git/user/functions/_main.sh ---

URL=$1

if [ -z "$URL" ]; then
    # No parameters passed, display AppleScript dialog
    SCRIPT=$(osascript <<EOD
    set userChoice to choose from list {"checkin", "checkout", "setup"} with prompt "Choose an action:"
    if userChoice is false then
        return ""
    else
        return item 1 of userChoice
    end if
EOD
)
    if [ -z "$SCRIPT" ]; then
        log_message "No action chosen. Exiting."
        echo "No action chosen. Exiting."
        exit 1
    fi
else
log_message "Started with URL: $URL"
    URLPATH="${URL#*//}"
    SCRIPT=$(echo "$URLPATH" | cut -d'/' -f1)
    PARAM=$(echo "$URLPATH" | cut -d'/' -f2)
    log_message "Script: $SCRIPT"
    log_message "Param: $PARAM"

fi

if [ "$SCRIPT" == "checkin" ]; then
    checkin "$PARAM"
elif [ "$SCRIPT" == "checkout" ]; then
    checkout "$PARAM"
elif [ "$SCRIPT" == "setup" ]; then
    setup "$PARAM"
fi
# --- End of /Users/shoek/Git Testing/finalcut-git/user/functions/_main.sh ---

