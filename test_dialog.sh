#!/bin/bash

echo "Testing AppleScript dialog..."

# Test the exact same AppleScript code used in the droplet
result=$(osascript -e 'display dialog "Enter a name for this card:" default answer "" buttons {"Cancel", "OK"} default button "OK"' 2>&1)
osascript_status=$?

echo "osascript_status: $osascript_status"
echo "result: $result"

# Parse the result
button_clicked=$(echo "$result" | sed -n 's/.*button returned:\(.*\), text returned.*/\1/p' | tr -d ', ')
card_name=$(echo "$result" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')

echo "button_clicked: '$button_clicked'"
echo "card_name: '$card_name'"

if [ "$button_clicked" = "Cancel" ]; then
    echo "User canceled"
elif [ -n "$card_name" ]; then
    echo "User entered: $card_name"
else
    echo "No card name entered"
fi 