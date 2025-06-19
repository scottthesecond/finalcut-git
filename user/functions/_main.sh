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
      
    # Check in operations (from submenus)
    "Check In "*)
      script="checkin"
      parameter=$(echo "$1" | sed 's/Check In //' | tr -d '"')
      ;;
      
    # Quick Save operations (from submenus)
    "Quick Save "*)
      script="checkpoint"
      parameter=$(echo "$1" | sed 's/Quick Save //' | tr -d '"')
      ;;
      
    # Checkout operations
    "Check Out Another Project")
      script="checkout"
      ;;
      
    # Direct project names (from checkout submenu)
    \"*\")
      # Check if this is a project name for checkout
      if repo_exists "$(echo "$1" | tr -d '"')" "$CHECKEDIN_FOLDER"; then
        script="checkout"
        parameter=$(echo "$1" | tr -d '"')
      else
        script="open"
        parameter=$(echo "$1" | tr -d '"')
      fi
      ;;
      
    # Navigation operations (legacy format)
    " ↳ Go To "*)
      script="open"
      parameter=$(echo "$1" | sed 's/ ↳ Go To //')
      ;;
      
    # Check in operations (legacy format)
    " ↳ Check In "*)
      script="checkin"
      parameter=$(echo "$1" | sed 's/ ↳ Check In //')
      ;;
      
    # New Project creation from submenu
    "New Project...")
      script="checkout"
      parameter="NEW"
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
      if [ "$parameter" = "NEW" ]; then
        # Prompt for new repo name using AppleScript
        new_repo_name=$(osascript -e 'display dialog "Enter the name of the new repository:" default answer ""' -e 'text returned of result')
        if [ -n "$new_repo_name" ]; then
          checkout "$new_repo_name" || handle_error "Check-out operation failed"
        fi
      else
        checkout "$parameter" || handle_error "Check-out operation failed"
      fi
      ;;
    "checkpoint")
      checkpoint "$parameter" || handle_error "Checkpoint operation failed"
      ;;
    "checkpointall") 
      checkpoint_all || handle_error "Checkpoint all operation failed"
      ;;
    "setup"|"Setup")
      setup "$parameter" || handle_error "Setup operation failed"
      ;;
    "open")
      log_message "Attempting to open $CHECKEDOUT_FOLDER/$parameter"
      if ! repo_exists "$parameter" "$CHECKEDOUT_FOLDER"; then
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

# Function to get recently checked out projects
get_recent_projects() {
    get_checkedin_repos
}

# Function to display the navbar menu
display_navbar_menu() {
    # Get checked out projects
    local checkedout_repos=($(get_checkedout_repos))
    
    if [ ${#checkedout_repos[@]} -eq 0 ]; then
        echo "DISABLED|(You do not currently have any projects checked out)"
    else
        for repo_name in "${checkedout_repos[@]}"; do
            local repo_path="$CHECKEDOUT_FOLDER/$repo_name"
            local CHECKEDOUT_FILE="$repo_path/.CHECKEDOUT"
            
            # Get last checkpoint time if available
            local last_checkpoint=""
            if [ -f "$CHECKEDOUT_FILE" ]; then
                last_checkpoint=$(grep 'LAST_COMMIT=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
            fi
            
            # Create submenu for this project
            if [ -n "$last_checkpoint" ]; then
                echo "SUBMENU|$repo_name|DISABLED|Last Autosave: $last_checkpoint|Check In \"$repo_name\"|Quick Save \"$repo_name\""
            else
                echo "SUBMENU|$repo_name|Check In \"$repo_name\"|Quick Save \"$repo_name\""
            fi
        done
    fi

    # Display menu separator
    echo "----"
    
    # Create submenu for checkout with recent projects
    local recent_projects=($(get_recent_projects))
    if [ ${#recent_projects[@]} -gt 0 ]; then
        local submenu_items=""
        for project in "${recent_projects[@]}"; do
            if [ -n "$submenu_items" ]; then
                submenu_items="$submenu_items|"
            fi
            submenu_items="$submenu_items\"$project\""
        done
        # Add divider and New Project option
        submenu_items="$submenu_items|----|New Project..."
        echo "SUBMENU|Check Out Another Project|$submenu_items"
    else
        echo "SUBMENU|Check Out Another Project|New Project..."
    fi
    
    # Display menu footer
    echo "----"
    echo "DISABLED|$APP_NAME Version $VERSION"
    echo "Setup"
    echo "----"
}

# Handle navbar mode display
if $navbar; then
    display_navbar_menu
    exit 0
fi

