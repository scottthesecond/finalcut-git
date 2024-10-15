#!/bin/bash
VERSION=2.0.3
APP_NAME=UNFlab
#!/bin/bash

#Variables
DATA_FOLDER="$HOME/fcp-git"
#REPO_FOLDER="$DATA_FOLDER/repos"
CHECKEDOUT_FOLDER="$DATA_FOLDER/checkedout"
CHECKEDIN_FOLDER="$DATA_FOLDER/.checkedin"
CONFIG_FILE="$DATA_FOLDER/.config"
LOG_FILE="$DATA_FOLDER/fcp-git.log"
selected_repo=""

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
	mkdir -p "$CHECKEDOUT_FOLDER"
	mkdir -p "$CHECKEDIN_FOLDER"

	# Write the server address and port to the .env file
	echo "SERVER_ADDRESS=$SERVER_ADDRESS" > "$CONFIG_FILE"
	echo "SERVER_PORT=$SERVER_PORT" >> "$CONFIG_FILE"
	echo "SERVER_PATH=$SERVER_PATH" >> "$CONFIG_FILE"

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
		ssh-keygen -t ed25519 -C "$email" -q -N "" -f "~/.ssh/id_ed25519"
		SSH_KEY_PUB="$SSH_DIR/id_ed25519.pub"
	fi

	# Return the SSH public key
	echo -e "\:\n"
	email=$(osascript -e "display dialog \"nYour public key is below.  Please copy the whole thing and give it to your manager:\" default answer \"$(cat "$SSH_KEY_PUB")\"" -e 'text returned of result')
}

# Function to select a repo using AppleScript
select_repo() {
    local enable_new="false"
    local folders=("$CHECKEDOUT_FOLDER"/*)
    local prompt_text="Select an existing repository:" # Default prompt

    # Check for passed arguments
    for arg in "$@"; do
        if [ "$arg" == "--allowNew" ]; then
            enable_new="true"
        elif [ "$arg" == "--checkedIn" ]; then
            folders=("$CHECKEDIN_FOLDER"/*)
        else
            prompt_text="$arg"  # Set the argument as the custom prompt
        fi
    done
   
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
    selected_repo=$(osascript -e "choose from list {$repo_list} with prompt \"$prompt_text\"")

    # Check if the user selected "New" (only if enabled)
    if [ "$selected_repo" == "false" ]; then
        # User pressed cancel
        exit 0
    elif [ "$enable_new" == "true" ] && [ "$selected_repo" == "New" ]; then
        # Ask the user to input a new repository name
        selected_repo=$(osascript -e 'display dialog "Enter the name of the new repository:" default answer ""' -e 'text returned of result')

        # Create the new repository folder
        #mkdir -p "$CHECKEDOUT_FOLDER/$selected_repo"
    fi

    # Navigate to the selected or newly created repository
    cd "$CHECKEDOUT_FOLDER/$selected_repo"
}

#!/bin/bash

# Function to check if files in the repository are open, excluding certain processes
check_open_files() {
    open_files=$(lsof +D "$CHECKEDOUT_FOLDER/$selected_repo" | grep -v "^COMMAND" | grep -vE "(bash|lsof|awk|grep|mdworker_|osascript)")
    if [ -n "$open_files" ]; then
        log_message "Files are still open:"
        log_message "$open_files"
        return 0  # Files are open
    else
        return 1  # No files are open
    fi
}

# Function to escape special characters for osascript
escape_for_applescript() {
    echo "$1" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed "s/'/\\'/g"
}


moveToHiddenCheckinFolder(){
    log_message "moving repo to .checkedin folder..."
    mv "$CHECKEDOUT_FOLDER/$selected_repo" "$CHECKEDIN_FOLDER/$selected_repo" || handle_error "Couldn't move $selected_repo to the checkedin folder – make sure you've closed all projects."

    log_message "Setting repository $selected_repo to read-only"
    chmod -R u-w "$CHECKEDIN_FOLDER/$selected_repo" || handle_error "Failed to set repository $selected_repo to read-only"
    log_message "Repository $selected_repo is now read-only"

}


commitAndPush() {

    # Get the current date and the user's name
    current_date=$(date +"%Y-%m-%d")
    user_name=$(whoami)

    #Get Commit Message
    commit_message_user=""
    commit_message_user=$(grep 'commit_message=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
    
    if [ -z "$commit_message_user" ]; then
        commit_message="Commit on $current_date by $user_name"
    else
        commit_message="$user_name: $commit_message"
    fi


    # Stage all changes, commit with the current date and username, and push
    log_message "Staging changes in $selected_repo"
    git add . >> "$LOG_FILE" 2>&1 || handle_error "Failed to stage changes in $selected_repo"
    log_message "Committing changes in $selected_repo"
    git commit -m "$commit_message" >> "$LOG_FILE" 2>&1 || handle_error "Git commit failed in $selected_repo"
    log_message "Pushing changes for $selected_repo"
    git push >> "$LOG_FILE" 2>&1 || handle_error "Git push failed for $selected_repo"
    log_message "Changes have been successfully checked in and pushed for $selected_repo."

}


checkpoint() {

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        cd "$CHECKEDOUT_FOLDER/$selected_repo"
    else
        select_repo "Which repository do you want to Checkpoint?"
    fi

    CHECKEDOUT_FILE="$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT"

    commit_message_user=""
    commit_message_user=$(grep 'commit_message=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)

    log_message "Current commit message: $commit_message_user"

    result=$(osascript -e "display dialog \"What did you change so far?\nI'll sync the project to the server (It'll stay checked out) with the log message below.\n\nIf you'll be working on something different going forward and would like to change your log message for autosaves after this, use Checkpoint w/ New Log Message.\" default answer \"$commit_message_user\" with title \"New Checkpoint\" buttons {\"Cancel\", \"Checkpoint\", \"Checkpoint and Change Message\"} default button \"Checkpoint\"")
    
    log_message "Dialog Result: $result"
    
        # Parse button clicked and commit message using sed
        button_clicked=$(echo "$result" | sed -n 's/.*button returned:\(.*\), text returned.*/\1/p' | tr -d ', ')
        commit_message=$(echo "$result" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')

        # Log the parsed values for debugging
        log_message "Button clicked: $button_clicked"
        log_message "Commit message: $commit_message"

    set_log_message
    
    if [ "$button_clicked" = "Checkpoint" ]; then

        display_dialog_timed "Creating Checkpoint..." "Uploading your changes to $selected_repo to the server...." "Hide"
        commitAndPush
        display_notification "Uploaded changes to $selected_repo." "A checkpoint for $selected_repo has been created sucessfully."
        hide_dialog

        # Code to execute when confirmed
        log_message "Confirmed with message: $commit_message"
        # Add your logic here for when the user confirms
    elif [ "$button_clicked" = "CheckpointandChangeMessage" ]; then
        
        nextResult=$(osascript -e "display dialog \"What are you working on now?\n\nI'll use this for autosaves going forward\" default answer \"$commit_message\" with title \"Checkpoint Message\" buttons {\"OK\"} default button \"OK\"")

        display_dialog_timed "Creating Checkpoint..." "Uploading your changes to $selected_repo to the server...." "Hide"
        commitAndPush
        
        commit_message=$(echo "$nextResult" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')
        set_log_message

        display_notification "Uploaded changes to $selected_repo." "A checkpoint for $selected_repo has been created sucessfully."
        hide_dialog

        log_message "Checkpoint Created and message changed to: $commit_message"

    else
        # Code to execute when canceled
        log_message "User canceled"
        # Add your logic here for when the user cancels
    fi



}


checkin() {

    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from checkout script: $selected_repo"
        cd "$CHECKEDOUT_FOLDER/$selected_repo"
    else
        select_repo "Which repository do you want to check in?"
    fi
    
    display_dialog_timed "Syncing Project" "Uploading your changes to $selected_repo to the server...." "Hide"

    # Check for open files before proceeding
    while check_open_files; do
        user_choice=$(osascript -e "display dialog \"There are files in this repository that are still open in other applications.  Please make sure everything is closed before checking in.\n\nYou can check the log to see which applications are using files in the repository.\" buttons {\"Check-in Anyway (This is a bad idea)\", \"I've Closed Them\"} default button \"I've Closed Them\"")

        if [[ "$user_choice" == "button returned:Check-in Anyway (This is a bad idea)" ]]; then
            log_message "User chose to proceed with check-in despite open files."
            break  # Proceed with check-in
        fi
    done


    # Remove checkedout files
    rm -f "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT" #V1 CHECKEDOUT File (remove once everyone is up-to-date)
    rm -f "$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT" #V2 .CHECKEDOUT File

    commitAndPush

    moveToHiddenCheckinFolder

    hide_dialog

    display_notification "Uploaded changes to $selected_repo." "$selected_repo has been sucessfully checked in."


#    osascript -e "display dialog \"Changes have been checked in and pushed for $selected_repo.\" buttons {\"OK\"} default button \"OK\""

    # Set the repository to read-only
    #echo "Repository $selected_repo is now read-only."
}




set_checkedout_file() {
    CHECKEDOUT_FILE="$CHECKEDOUT_FOLDER/$selected_repo/.CHECKEDOUT"

}

set_log_message() {
    set_checkedout_file
    CURRENT_USER=$(whoami)

    echo "checked_out_by=$CURRENT_USER" > "$CHECKEDOUT_FILE"
    echo "commit_message=$commit_message" >> "$CHECKEDOUT_FILE"

}

cancel_checkout() {

    handle_error "$1"
    log_message "Cancelling checkout.  running git reset."
    git reset --hard HEAD

    moveToHiddenCheckinFolder

    log_message "Exiting."
    exit 1

}

checkout() {
    # Check if the repository is passed as an argument
    if [ -n "$1" ]; then
        selected_repo="$1"
        log_message "Repository passed from command: $selected_repo"
    else
        select_repo "Check out a recent repository, or a new one?" --allowNew --checkedIn
    fi

    display_dialog_timed "Syncing Project" "Syncing $selected_repo from the server...." "Hide"

    set_checkedout_file

    # Check if the repository exists locally
    if [ ! -d "$CHECKEDOUT_FOLDER/$selected_repo" ]; then
        log_message "Repo $selected_repo is not already checked out, seeing if we have it in the checkedin cache..."
        
        if [ ! -d "$CHECKEDIN_FOLDER/$selected_repo" ]; then
            #it is not cached, clone it
            log_message "Repository $selected_repo does not exist locally. Cloning..."
            
            git clone "ssh://git@$SERVER_ADDRESS:$SERVER_PORT/$SERVER_PATH/$selected_repo.git" "$CHECKEDOUT_FOLDER/$selected_repo" >> "$LOG_FILE" 2>&1 || handle_error "Git clone failed for $new_repo"

            log_message "Repository cloned: $selected_repo"
        else
            # it is cached, copy it to the checked out folder
            log_message "Repository $selected_repo is cached, but not checked out."
            log_message "Making repository $selected_repo writable"
            chmod -R u+w "$CHECKEDIN_FOLDER/$selected_repo" || cancel_checkout "Failed to make repository $selected_repo writable"
            log_message "moving repo to checkedout folder..."
            mv "$CHECKEDIN_FOLDER/$selected_repo" "$CHECKEDOUT_FOLDER/$selected_repo" || cancel_checkout "Couldn't move $selected_repo to the checked out folder"
        fi

    else
        log_message "Selected repo already checked out: $selected_repo"
    fi
    
    chmod -R u+w "$CHECKEDOUT_FOLDER/$selected_repo" || cancel_checkout "Failed to make repository $selected_repo writable"
    echo "Repository $selected_repo is now writable."
    cd "$CHECKEDOUT_FOLDER/$selected_repo"

    log_message "Running git pull in $selected_repo"
    git pull >> "$LOG_FILE" 2>&1 || cancel_checkout "Git pull failed for $selected_repo"

    # Navigate to the selected repository
    cd "$CHECKEDOUT_FOLDER/$selected_repo"


    # Check if the repository is already checked out
    if [ -f "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT" ] || [ -f "$CHECKEDOUT_FILE" ]; then
        if [ -f "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT" ]; then
            checked_out_by=$(cat "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT")
        elif [ -f "$CHECKEDOUT_FILE" ]; then
            checked_out_by=$(grep 'checked_out_by=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
            commit_message=$(grep 'commit_message=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
        fi

        if [ "$checked_out_by" != "$CURRENT_USER" ]; then
            
            log_message "Repository is already checked out by $checked_out_by"
            hide_dialog
            osascript -e "display dialog \"Repository is already checked out by $checked_out_by.\nReason: $commit_message\" buttons {\"OK\"} default button \"OK\""
            moveToHiddenCheckinFolder
            exit 1
        fi

    else

        #Get the commit message
        commit_message=$(osascript -e 'display dialog "Let your teammates know why you have the library checked out:" default answer "" with title "Checkout Log"' -e 'text returned of result')

        set_log_message

        #In case I can't update everyone at the same time, let's create the old checkedout file too:
        echo "$CURRENT_USER" > "$CHECKEDOUT_FOLDER/$selected_repo/CHECKEDOUT"

        git add "$CHECKEDOUT_FILE" >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to add CHECKEDOUT file."
        git commit -m "Checked out by $CURRENT_USER" >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to commit CHECKEDOUT file."
        git push >> "$LOG_FILE" 2>&1 || cancel_checkout "Failed to push CHECKEDOUT file."
        log_message "Repository checked out by $CURRENT_USER"
    fi
    
    hide_dialog

    create_settings_plist

    display_notification "Checked out $selected_repo." "The project is ready to work on." "When you're done, launch UNFlab and select 'checkin', then $selected_repo"

    open_fcp_or_directory

    # Use AppleScript to display two buttons
    #response=$(osascript -e "display dialog \"You are now checked out into $selected_repo.\n\nYou can either press leave this window open and press 'Check In Now' when you are done making changes, or you can hide this window and check the project in with UNFlab later.\" buttons {\"Check In Now\", \"Hide UNFLab\"} default button \"Check In Now\"")

    # Check if the user selected 'Check In'
    #if [[ "$response" == "button returned:Check In Now" ]]; then
    #    checkin "$selected_repo"
    #else
    #    osascript -e "display dialog \"When you're finished editing, launch UNFlab, choose 'Check In', and select $selected_repo.\" buttons {\"OK\"} default button \"OK\""
    #fi

}

# Load the .config file (for server and port if needed)
if [ -f "$CONFIG_FILE" ]; then
    export $(grep -v '^#' "$CONFIG_FILE" | xargs)
else
    setup
    # echo ".config file not found in $CONFIG_FILE!"
    # exit 1
fi

# Function to display dialog and store its process ID
display_dialog_timed() {
  local TITLE="$1"
  local DIALOG_TEXT="$2"
  local DISMISS_TEXT="$3"

  # Run AppleScript in the background
  osascript <<EOF &
set dialogTimeout to 60
set theDialog to display dialog "$DIALOG_TEXT" buttons {"$DISMISS_TEXT"} default button 1 with title "$TITLE" giving up after dialogTimeout
EOF

  # Store the background process ID
  DIALOG_PID=$!
}

# Function to hide (kill) the dialog
hide_dialog() {
  if [[ -n "$DIALOG_PID" ]]; then
    kill "$DIALOG_PID" &> /dev/null
    echo "Dialog with PID $DIALOG_PID has been hidden."
  else
    echo "No dialog is currently active."
  fi
}


# Function to display a macOS notification
display_notification() {
  local TITLE="$1"
  local MESSAGE="$2"
  local SUBTITLE="$3"

  osascript <<EOF
display notification "$MESSAGE" with title "$TITLE" subtitle "$SUBTITLE"
EOF
}


# Function to find the FCP bundle
find_fcp_bundles() {
    find "$CHECKEDOUT_FOLDER/$selected_repo" -type d -name "*.fcpbundle" -print0
}

# Function to create Settings.plist if it doesn't exist
create_settings_plist() {

    default_settings_file=$(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>backupsEnabled</key>
	<true/>
	<key>cacheLocation</key>
	<data>
	Ym9va6wFAAAAAAQQMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkAQA
	AAcAAAABAQAAVm9sdW1lcwAcAAAAAQEAAFVORiAtIEFjdGl2ZSBQcm9qZWN0IFNjcmF0
	Y2gEAAAAAQEAAFRlbXAFAAAAAQEAAENBQ0hFAAAAEAAAAAEGAAAEAAAAFAAAADgAAABE
	AAAACAAAAAQDAAAbQgAAAAAAAAAAAAABCgAAEAAAAAEGAABsAAAAfAAAAHwAAAB8AAAA
	CAAAAAAEAABBxl+UPyc8BhgAAAABAgAAAgAAAAAAAAAPAQAAAAAAAAABAAAAAAAANQAA
	AAEJAABmaWxlOi8vL1ZvbHVtZXMvVU5GJTIwLSUyMEFjdGl2ZSUyMFByb2plY3QlMjBT
	Y3JhdGNoLwAAAAgAAAAEAwAAAAAAANAHAAAIAAAAAAQAAEHDKrQzuaucGAAAAAECAAAA
	AAAAAAAAAO8TAAABAAAAAAAAAAAAAAAlAAAAAQEAAC9Wb2x1bWVzL1VORiAtIEFjdGl2
	ZSBQcm9qZWN0IFNjcmF0Y2gAAABDAAAAAQkAAHNtYjovL1NIb2VrLUFkbWluQHVubmFt
	ZWRuYXMwMi9VTkYlMjAtJTIwQWN0aXZlJTIwUHJvamVjdCUyMFNjcmF0Y2gACAAAAAEJ
	AABmaWxlOi8vLw0AAAABAQAATWFjT1MgU2VxdW9pYQAAAAgAAAAEAwAAAFChG3MAAAAI
	AAAAAAQAAEHGV/o4gAAAJAAAAAEBAAAwQjk3MEVGQy1EREQ4LTRCRjgtOUY1NC0wM0JG
	MDJDMTQyNkQYAAAAAQIAAIEAAAABAAAA7xMAAAEAAAAAAAAAAAAAAAEAAAABAQAALwAA
	AGAAAAD+////APAAAAAAAAAHAAAAAiAAAFwCAAAAAAAABSAAAMgBAAAAAAAAECAAANgB
	AAAAAAAAESAAABACAAAAAAAAEiAAAPABAAAAAAAAEyAAAAACAAAAAAAAICAAADwCAAAA
	AAAABAAAAAMDAAAA8AAABAAAAAMDAAAAAAAABAAAAAMDAAABAAAAFAAAAAEGAADQAgAA
	3AIAAOgCAADcAgAA3AIAAA0AAAABAQAAcHVibGljLmZvbGRlcgAAAB4AAAABAQAATlNV
	UkxWb2x1bWVVUkxGb3JSZW1vdW50aW5nS2V5AAARAAAAAQEAAE5TVVJMVm9sdW1lVVJM
	S2V5AAAAMAAAAAEBAAAvVm9sdW1lcy9VTkYgLSBBY3RpdmUgUHJvamVjdCBTY3JhdGNo
	L1RlbXAvQ0FDSEXiAAAAAQIAADRjZjE1ZmI1MDE5YzA5NmQ3ODhhZTFjOTBhNTQ4MTkz
	ODQ5MGU3OGYxNDQxOGUwNTgzOWI3ODJiZGQwMzdkZTI7MDA7MDAwMDAwMDA7MDAwMDAw
	MDA7MDAwMDAwMDA7MDAwMDAwMDAwMDAwMDAyMDtjb20uYXBwbGUuYXBwLXNhbmRib3gu
	cmVhZC13cml0ZTswMTszNjAwMDAxZjswMDAwMDAwMDAwMjU1NGI2OzEyOy92b2x1bWVz
	L3VuZiAtIGFjdGl2ZSBwcm9qZWN0IHNjcmF0Y2gvdGVtcC9jYWNoZQAAAOQAAAD+////
	AQAAAGgCAAASAAAABBAAAFQAAAAAAAAABRAAAIQAAAAAAAAAEBAAAKwAAAAAAAAAQBAA
	AJwAAAAAAAAAACAAAPQCAAAAAAAAAiAAAEwBAAAAAAAABSAAAMwAAAAAAAAAECAAABQA
	AAAAAAAAEiAAAAwBAAAAAAAAEyAAABwBAAAAAAAAICAAACwBAAAAAAAAUCAAAHwBAAAA
	AAAAF/AAAEQAAAAAAAAAgPAAAKQDAAAAAAAAAP8AAGwDAAAAAAAABAAPABADAAAAAAAA
	KAMAgHwBAAAAAAAAUAMAgMwAAAAAAAAA
	</data>
	<key>mediaLocation</key>
	<data>
	Ym9va6wFAAAAAAQQMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAkAQA
	AAcAAAABAQAAVm9sdW1lcwAcAAAAAQEAAFVORiAtIEFjdGl2ZSBQcm9qZWN0IFNjcmF0
	Y2gEAAAAAQEAAFRlbXAFAAAAAQEAAE1FRElBAAAAEAAAAAEGAAAEAAAAFAAAADgAAABE
	AAAACAAAAAQDAAAbQgAAAAAAAAAAAAABCgAAEAAAAAEGAABsAAAAfAAAAHwAAAB8AAAA
	CAAAAAAEAABBxl+UPPhl+BgAAAABAgAAAgAAAAAAAAAPAQAAAAAAAAABAAAAAAAANQAA
	AAEJAABmaWxlOi8vL1ZvbHVtZXMvVU5GJTIwLSUyMEFjdGl2ZSUyMFByb2plY3QlMjBT
	Y3JhdGNoLwAAAAgAAAAEAwAAAAAAANAHAAAIAAAAAAQAAEHDKrQzuaucGAAAAAECAAAA
	AAAAAAAAAO8TAAABAAAAAAAAAAAAAAAlAAAAAQEAAC9Wb2x1bWVzL1VORiAtIEFjdGl2
	ZSBQcm9qZWN0IFNjcmF0Y2gAAABDAAAAAQkAAHNtYjovL1NIb2VrLUFkbWluQHVubmFt
	ZWRuYXMwMi9VTkYlMjAtJTIwQWN0aXZlJTIwUHJvamVjdCUyMFNjcmF0Y2gACAAAAAEJ
	AABmaWxlOi8vLw0AAAABAQAATWFjT1MgU2VxdW9pYQAAAAgAAAAEAwAAAFChG3MAAAAI
	AAAAAAQAAEHGV/o4gAAAJAAAAAEBAAAwQjk3MEVGQy1EREQ4LTRCRjgtOUY1NC0wM0JG
	MDJDMTQyNkQYAAAAAQIAAIEAAAABAAAA7xMAAAEAAAAAAAAAAAAAAAEAAAABAQAALwAA
	AGAAAAD+////APAAAAAAAAAHAAAAAiAAAFwCAAAAAAAABSAAAMgBAAAAAAAAECAAANgB
	AAAAAAAAESAAABACAAAAAAAAEiAAAPABAAAAAAAAEyAAAAACAAAAAAAAICAAADwCAAAA
	AAAABAAAAAMDAAAA8AAABAAAAAMDAAAAAAAABAAAAAMDAAABAAAAFAAAAAEGAADQAgAA
	3AIAAOgCAADcAgAA3AIAAA0AAAABAQAAcHVibGljLmZvbGRlcgAAAB4AAAABAQAATlNV
	UkxWb2x1bWVVUkxGb3JSZW1vdW50aW5nS2V5AAARAAAAAQEAAE5TVVJMVm9sdW1lVVJM
	S2V5AAAAMAAAAAEBAAAvVm9sdW1lcy9VTkYgLSBBY3RpdmUgUHJvamVjdCBTY3JhdGNo
	L1RlbXAvTUVESUHiAAAAAQIAADJkMDM3MmNmZjc4Y2FmZmQzYjhjMDA1Y2MwNWMyYmFj
	NmMxMTMwZmY2ZGI4YjY0NWY4YzYwNmY0NzY2MDEzNTU7MDA7MDAwMDAwMDA7MDAwMDAw
	MDA7MDAwMDAwMDA7MDAwMDAwMDAwMDAwMDAyMDtjb20uYXBwbGUuYXBwLXNhbmRib3gu
	cmVhZC13cml0ZTswMTszNjAwMDAxZjswMDAwMDAwMDAwMjU1NGI1OzEyOy92b2x1bWVz
	L3VuZiAtIGFjdGl2ZSBwcm9qZWN0IHNjcmF0Y2gvdGVtcC9tZWRpYQAAAOQAAAD+////
	AQAAAGgCAAASAAAABBAAAFQAAAAAAAAABRAAAIQAAAAAAAAAEBAAAKwAAAAAAAAAQBAA
	AJwAAAAAAAAAACAAAPQCAAAAAAAAAiAAAEwBAAAAAAAABSAAAMwAAAAAAAAAECAAABQA
	AAAAAAAAEiAAAAwBAAAAAAAAEyAAABwBAAAAAAAAICAAACwBAAAAAAAAUCAAAHwBAAAA
	AAAAF/AAAEQAAAAAAAAAgPAAAKQDAAAAAAAAAP8AAGwDAAAAAAAABAAPABADAAAAAAAA
	KAMAgHwBAAAAAAAAUAMAgMwAAAAAAAAA
	</data>
</dict>
</plist>
EOF
)

    find_fcp_bundles | while IFS= read -r -d '' bundle_path; do
        plist_path="$bundle_path/Settings.plist"
        if [ ! -f "$plist_path" ]; then
            # Create the Settings.plist file with the specified content
            printf '%s\n' "$default_settings_file" > "$plist_path"
            log_message "Created Settings.plist in $bundle_path"
        else
            log_message "Settings.plist already exists in $bundle_path"
        fi
    done    
}


# Function to open the FCP bundle or directory
open_fcp_or_directory() {
    found_bundle=false
    find_fcp_bundles | while IFS= read -r -d '' bundle_path; do
        found_bundle=true
        open "$bundle_path"
    done

    # If no bundle is found, open the directory
    if [ "$found_bundle" = false ]; then
        log_message "No .fcpbundle found. Opening the directory."
        open "$CHECKEDOUT_FOLDER/$selected_repo"
    fi
}



navbar=false
script=""
parameter=""

# Function to parse URL format
parse_url() {
  url=$1
  # Extract the script and parameter from the URL (fcpgit://script/parameter)
  script=$(echo $url | cut -d '/' -f 3)
  parameter=$(echo $url | cut -d '/' -f 4)
}

# Parse arguments
while [[ "$1" != "" ]]; do
  case $1 in
    -navbar)
      navbar=true
      ;;
    fcpgit://*)
      parse_url "$1"
      ;;
    " ↳ Quick Save "*)
      script="checkpoint"
      parameter=$(echo "$1" | sed 's/ ↳ Quick Save //')
      ;;
    " ↳ Check In "*)
      script="checkin"
      parameter=$(echo "$1" | sed 's/ ↳ Check In //')
      ;;
    "Check Out Another Project")
      script="checkout"
      ;;
    "Setup")
      script="setup"
      ;;
    " ↳ Go To "*)
      script="open"
      parameter=$(echo "$1" | sed 's/ ↳ Go To //')
      ;;
    \"*\")
      # Remove the surrounding quotes from the project name
      script="open"
      parameter=$(echo "$1" | tr -d '"')
      ;;
    *)
      if [ -z "$script" ]; then
        script=$1
      elif [ -z "$parameter" ]; then
        parameter=$1
      fi
      ;;
  esac
  shift
done

log_message "Navbar: $navbar"
log_message "Script: $script"

# Remove surrounding quotes from the parameter if present
parameter=$(echo "$parameter" | tr -d '"')

log_message "Parameter: $parameter"

if [ -n "$script" ]; then
  case $script in
    "checkin")
      checkin "$parameter"
      ;;
    "checkout")
      checkout "$parameter"
      ;;
    "checkpoint")
      checkpoint "$parameter"
      ;;
    "setup")
      setup "$parameter"
      ;;
    "open")
      selected_repo="$parameter"
      log_message "Attempting to open $CHECKEDOUT_FOLDER/$parameter"
      open_fcp_or_directory
      ;;
    *)
      echo "Unknown script: $script"
      ;;
  esac
fi

if $NAVBAR_MODE; then

    # Get checked out projects...
    folders=("$CHECKEDOUT_FOLDER"/*)

    # Check if there are any repositories
    if [ "${folders[0]}" = "$CHECKEDOUT_FOLDER/*" ]; then
        echo "No projects are checked out."
    else
        for i in "${!folders[@]}"; do
            folder_name=$(basename "${folders[$i]}")
            # Output action and folder name together
            echo "\"$folder_name\""
            echo " ↳ Check In \"$folder_name\""
            #echo " ↳ Go To \"$folder_name\""
            echo " ↳ Quick Save \"$folder_name\""

        done
    fi
    echo "----"
    echo "Check Out Another Project"
    echo "----"
    echo "$APP_NAME Version $VERSION"
    echo "Setup"
    echo "----"
    #log_message "Displayed menu options: checkin, checkout, setup"
    exit 0
fi

