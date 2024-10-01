INPUT=$1
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
        INPUT="$arg"  # Assume other arguments are input
        log_message "Processing argument: $INPUT"
    fi
done


log_message "Navbar mode: $NAVBAR_MODE"

if $NAVBAR_MODE; then
    log_message "Running in navbar mode"
    if [[ -z "$INPUT" || "$INPUT" == "-navbar" ]]; then
        # Navbar mode with no specific script input; display menu options
        echo "checkin"
        echo "checkout"
        echo "setup"
        echo "more"  # For testing...
        log_message "Displayed menu options: checkin, checkout, setup"
        exit 0
    else
        # Script is selected from navbar menu, process input as script action
        SCRIPT="$INPUT"
        log_message "Selected script from navbar: $SCRIPT"
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
if [ "$SCRIPT" == "checkin" ]; then
    log_message "Executing checkin with param: $PARAM"
    checkin "$PARAM"
elif [ "$SCRIPT" == "checkout" ]; then
    log_message "Executing checkout with param: $PARAM"
    checkout "$PARAM"
elif [ "$SCRIPT" == "setup" ]; then
    log_message "Executing setup with param: $PARAM"
    setup "$PARAM"
elif [ "$SCRIPT" == "more" ]; then
    log_message "Selected 'more' option, displaying sub-options"
    echo "suboption1"
    echo "suboption2"
    echo "suboption3"
    log_message "Displayed sub-options: suboption1, suboption2, suboption3"
    exit 0
else
    log_message "No valid script action found. Exiting."
    echo "Invalid action. Exiting."
fi