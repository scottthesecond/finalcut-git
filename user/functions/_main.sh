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