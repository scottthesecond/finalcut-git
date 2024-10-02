NAVBAR_MODE=false
SCRIPT=""
PARAM=""

migration1.3
log_message "Script started with arguments: $@"

# Check if -navbar is present in the arguments
for arg in "$@"; do
    if [ "$arg" == "-navbar" ]; then
        NAVBAR_MODE=true
        log_message "Found -navbar argument"
    else
        if [ -z "$INPUT" ]; then
            INPUT="$arg"  # Only set INPUT once for the first non-navbar argument
        fi
        log_message "Processing argument: $arg"
    fi
done

log_message "Navbar mode: $NAVBAR_MODE"

if $NAVBAR_MODE; then
    log_message "Running in navbar mode"
    if [[ -z "$INPUT" || "$INPUT" == "-navbar" ]]; then

        # Get checked out projects...
        folders=("$CHECKEDOUT_FOLDER"/*)

        # Check if there are any repositories
        if [ ${#folders[@]} -eq 0 ]; then
            echo "(You do not currently have any projects checked out)"
        else
            for i in "${!folders[@]}"; do
                folder_name=$(basename "${folders[$i]}")
                # Output action and folder name together
                echo "Check In \"$folder_name\""
            done
        fi

        echo "checkout"
        echo "----"
        echo "setup"
        echo "----"
        log_message "Displayed menu options: checkin, checkout, setup"
        exit 0
    else
        # Script is selected from navbar menu, process input as script action
        SCRIPT=$(echo "$INPUT" | cut -d' ' -f1)  # Extract the action (e.g., "checkout")
        PARAM=$(echo "$INPUT" | cut -d' ' -f2-)  # Extract the parameter (if any)
        log_message "Selected script: $SCRIPT, with param: $PARAM"
    fi
else
    log_message "Not in navbar mode, processing normally"
    # Handle URL or prompt-based input
    if [[ -z "$INPUT" ]]; then
        log_message "No input provided, prompting user with AppleScript"
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
        log_message "User selected: $SCRIPT"
        if [ -z "$SCRIPT" ]; then
            log_message "No action chosen. Exiting."
            echo "No action chosen. Exiting."
            exit 1
        fi
    elif [[ "$INPUT" == *"://"* ]]; then
        # Input is a URL, process accordingly
        log_message "Input is a URL: $INPUT"
        URLPATH="${INPUT#*//}"
        SCRIPT=$(echo "$URLPATH" | cut -d'/' -f1)
        PARAM=$(echo "$URLPATH" | cut -d'/' -f2)
        log_message "Script: $SCRIPT"
        log_message "Param: $PARAM"
    fi
fi

log_message "Final script: $SCRIPT"
log_message "Final param: $PARAM"

# Execute based on the chosen script action
if [ "$SCRIPT" == "Check" ] && [[ "$PARAM" == In* ]]; then
    # Extract folder name from PARAM, assuming "Check In folder_name"
    FOLDER=$(echo "$PARAM" | cut -d'"' -f2)
    log_message "Executing checkin with folder: $FOLDER"
    checkin "$FOLDER"
elif [ "$SCRIPT" == "checkout" ] && [ -n "$PARAM" ]; then
    log_message "Executing checkout with param: $PARAM"
    checkout "$PARAM"
elif [ "$SCRIPT" == "checkout" ]; then
    log_message "Executing checkout with no param"
    checkout
elif [ "$SCRIPT" == "setup" ]; then
    log_message "Executing setup with param: $PARAM"
    setup "$PARAM"
else
    log_message "No valid script action found. Exiting."
    echo "Invalid action. Exiting."
fi