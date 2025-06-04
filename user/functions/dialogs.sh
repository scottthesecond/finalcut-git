# Function to display dialog and store its process ID
display_dialog_timed() {
  local TITLE="$1"
  local DIALOG_TEXT="$2"
  local DISMISS_TEXT="$3"

  # Skip dialog if in silent mode
  if [ "$SILENT_MODE" = true ]; then
    return
  fi

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

  # Skip notification if in silent mode
  if [ "$SILENT_MODE" = true ]; then
    return
  fi

  osascript <<EOF
display notification "$MESSAGE" with title "$TITLE" subtitle "$SUBTITLE"
EOF
}
