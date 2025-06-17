#log_message "-----   $APP_NAME ($VERSION) MAIN LOOP STARTED   -----"

navbar=false
script=""
parameter=""
SILENT_MODE=false

enable_auto_checkpoint


# Function to parse URL format
parse_url() {
  local url="$1"
  if [[ ! "$url" =~ ^fcpgit:// ]]; then
    log_message "Error: Invalid URL format. Expected fcpgit://"
    return 1
  fi
  
  # Remove the protocol prefix
  local path="${url#fcpgit://}"
  
  # Split the remaining path into script and parameter
  script="${path%%/*}"
  parameter="${path#*/}"
  
  log_message "Parsed URL - Script: $script, Parameter: $parameter"
}

# Parse arguments
while [[ "$1" != "" ]]; do
  case $1 in
    # Mode flags
    -navbar)
      navbar=true
      ;;
    --silent)
      SILENT_MODE=true
      ;;
      
    # URL-based commands
    fcpgit://*)
      log_message "(LAUNCHED VIA URL)"
      parse_url "$1"
      ;;
      
    # Checkpoint operations
    checkpointall|"Quick Save")
      log_message "(CHECKPOINTALL)"
      script="checkpointall"
      ;;
      
    # Check in operations
    " ↳ Check In "*)
      script="checkin"
      parameter=$(echo "$1" | sed 's/ ↳ Check In //')
      ;;
      
    # Checkout operations
    "Check Out Another Project")
      script="checkout"
      ;;
      
    # Navigation operations
    " ↳ Go To "*)
      script="open"
      parameter=$(echo "$1" | sed 's/ ↳ Go To //')
      ;;
      
    # Quoted project names
    \"*\")
      script="open"
      parameter=$(echo "$1" | tr -d '"')
      ;;
      
    # Default case for direct script/parameter pairs
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

# Clean up parameter by removing surrounding quotes
parameter=$(echo "$parameter" | tr -d '"')

# Log the final script and parameter values
log_message "Script: $script"
log_message "Parameter: $parameter"

# Export SILENT_MODE for child scripts
export SILENT_MODE

# Execute the requested script if one was specified
if [ -n "$script" ]; then
  case $script in
    "checkin")
      checkin "$parameter" || handle_error "Check-in operation failed"
      ;;
    "checkout")
      checkout "$parameter" || handle_error "Check-out operation failed"
      ;;
    "checkpoint")
      checkpoint "$parameter" || handle_error "Checkpoint operation failed"
      ;;
    "checkpointall") 
      checkpoint_all || handle_error "Checkpoint all operation failed"
      ;;
    "setup")
      setup "$parameter" || handle_error "Setup operation failed"
      ;;
    "open")
      log_message "Attempting to open $CHECKEDOUT_FOLDER/$parameter"
      if [ ! -d "$CHECKEDOUT_FOLDER/$parameter" ]; then
        handle_error "Project directory not found: $parameter"
      else
        open "$CHECKEDOUT_FOLDER/$parameter" || handle_error "Failed to open project: $parameter"
      fi
      ;;
    *)
      handle_error "Unknown script: $script"
      ;;
  esac
fi

# Function to display the navbar menu
display_navbar_menu() {
    # Get checked out projects
    if [ -d "$CHECKEDOUT_FOLDER" ]; then
        folders=("$CHECKEDOUT_FOLDER"/*)

        # Check if there are any repositories
        if [ ${#folders[@]} -eq 1 ] && [ ! -e "${folders[0]}" ]; then
            echo "(You do not currently have any projects checked out)"
        else
            for folder in "${folders[@]}"; do
                folder_name=$(basename "$folder")
                CHECKEDOUT_FILE="$folder/.CHECKEDOUT"
                
                # Output project name
                echo "\"$folder_name\""

                # Display last checkpoint time if available
                if [ -f "$CHECKEDOUT_FILE" ]; then
                    last_checkpoint=$(grep 'LAST_COMMIT=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
                    echo " ↳ Last Autosave: $last_checkpoint"
                fi

                echo " ↳ Check In \"$folder_name\""
            done
        fi
    else
        echo "(You do not currently have any projects checked out)"
    fi

    # Display menu footer
    echo "----"
    echo "Check Out Another Project"
    echo "----"
    echo "$APP_NAME Version $VERSION"
    echo "Quick Save"
    echo "Setup"
    echo "----"
}

# Handle navbar mode display
if $NAVBAR_MODE; then
    display_navbar_menu
    exit 0
fi

