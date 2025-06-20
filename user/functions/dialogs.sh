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

# Function to cleanly exit the application using Platypus format
clean_exit() {
    local exit_code="${1:-0}"
    
    # Use Platypus QUITAPP for clean termination
    echo "QUITAPP"
    exit "$exit_code"
}

# Progress bar output functions
show_progress() {
    local percentage="$1"
    if [ "$progressbar" = true ]; then
        echo "PROGRESS:$percentage"
    fi
}

show_details() {
    local message="$1"
    if [ "$progressbar" = true ]; then
        echo "$message"
    fi
}

show_details_on() {
    if [ "$progressbar" = true ]; then
        echo "DETAILS:SHOW"
    fi
}

show_details_off() {
    if [ "$progressbar" = true ]; then
        echo "DETAILS:HIDE"
    fi
}

# Function to format and display GIT output in a user-friendly way
# Parameters:
#   $1: git_output - The raw GIT command output
#   $2: operation - The GIT operation being performed (e.g., "push", "pull", "clone")
show_git_output() {
    local git_output="$1"
    local operation="$2"
    
    if [ "$progressbar" = true ] && [ -n "$git_output" ]; then
        # Split output into lines and process each one
        while IFS= read -r line; do
            # Skip empty lines
            if [ -n "$line" ]; then
                # Format common GIT messages for better readability
                case "$line" in
                    *"Cloning into"*)
                        show_details "📥 Cloning repository..."
                        ;;
                    *"remote: Counting objects"*)
                        show_details "📊 Counting objects..."
                        ;;
                    *"remote: Compressing objects"*)
                        show_details "🗜️  Compressing objects..."
                        ;;
                    *"Receiving objects"*)
                        show_details "⬇️  Downloading files..."
                        ;;
                    *"Resolving deltas"*)
                        show_details "🔗 Resolving changes..."
                        ;;
                    *"Unpacking objects"*)
                        show_details "📦 Unpacking files..."
                        ;;
                    *"Counting objects"*)
                        show_details "📊 Counting local objects..."
                        ;;
                    *"Compressing objects"*)
                        show_details "🗜️  Compressing local objects..."
                        ;;
                    *"Writing objects"*)
                        show_details "⬆️  Uploading files..."
                        ;;
                    *"Delta compression"*)
                        show_details "🔗 Compressing changes..."
                        ;;
                    *"To "*)
                        show_details "🌐 Connected to server"
                        ;;
                    *"From "*)
                        show_details "🌐 Connected to server"
                        ;;
                    *"Already up to date"*)
                        show_details "✅ Already up to date"
                        ;;
                    *"Updating "*)
                        show_details "🔄 Updating files..."
                        ;;
                    *"Fast-forward"*)
                        show_details "⚡ Fast-forward merge"
                        ;;
                    *"Merge made by"*)
                        show_details "🔀 Merge completed"
                        ;;
                    *"create mode"*|*"delete mode"*|*"rename"*)
                        show_details "📝 File changes detected"
                        ;;
                    *"insertions"*|*"deletions"*)
                        show_details "📊 Processing changes..."
                        ;;
                    *)
                        # For other output, show it as-is but limit length
                        if [ ${#line} -gt 80 ]; then
                            show_details "${line:0:77}..."
                        else
                            show_details "$line"
                        fi
                        ;;
                esac
            fi
        done <<< "$git_output"
    fi
}
