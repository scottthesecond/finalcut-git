#log_message "-----   $APP_NAME ($VERSION) MAIN LOOP STARTED   -----"

navbar=false
progressbar=false
droplet=false
script=""
parameter=""
SILENT_MODE=false
DEBUG_MODE=false

# Function to launch progress bar app for long operations
launch_progress_app() {
    local operation="$1"
    local repo_name="$2"
    local additional_param="$3"
    
    # Log with operation-specific context
    case "$operation" in
        "offload")
            log_message "launch_progress_app called with: operation='$operation', input_path='$repo_name', source_name='$additional_param'"
            ;;
        "checkin"|"checkout")
            log_message "launch_progress_app called with: operation='$operation', repo_name='$repo_name', commit_message='$additional_param'"
            ;;
        *)
            log_message "launch_progress_app called with: operation='$operation', repo_name='$repo_name', additional_param='$additional_param'"
            ;;
    esac
    
    # Get the path to the bundled progress bar app
    # SCRIPT_DIR now points to the main app's Resources folder (thanks to vars.sh fix)
    local progress_app_path="${SCRIPT_DIR}/UNFlab Progress.app"
    
    log_message "Progress app path: $progress_app_path"
    log_message "SCRIPT_DIR: $SCRIPT_DIR"
    
    # Check if the app exists
    if [ -d "$progress_app_path" ]; then
        log_message "Progress app found at bundled location"
        log_message "Attempting to launch: open -n '$progress_app_path' --args '$operation' '$repo_name' '$additional_param'"
        open -n "$progress_app_path" --args "$operation" "$repo_name" "$additional_param"
        log_message "Launch command completed"
    else
        log_message "Progress app not found at bundled location, trying Applications folder"
        # Fallback: try to find it in Applications
        log_message "Attempting to launch: open -n -a 'UNFlab Progress' --args '$operation' '$repo_name' '$additional_param'"
        open -n -a "UNFlab Progress" --args "$operation" "$repo_name" "$additional_param"
        log_message "Fallback launch command completed"
    fi
}

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

# Export SILENT_MODE for child scripts
export SILENT_MODE
export DEBUG_MODE
export navbar
export progressbar
export droplet

# Check for droplet mode first (before argument parsing)
if [[ "$1" == "-droplet" ]]; then
    droplet=true
    shift  # Remove the -droplet flag
    
    log_message "Running in droplet mode"
    
    # If no arguments left, just exit silently (opened directly)
    if [ $# -eq 0 ]; then
        log_message "Droplet opened directly (no files/folders dropped), exiting."
        exit 0
    fi
    
    # In droplet mode, treat all remaining arguments as folders to offload
    for dropped_item in "$@"; do
        log_message "Processing dropped item: $dropped_item"
        
        if [ -d "$dropped_item" ]; then
            log_message "Dropped item is a directory, prompting for card name"
            
            # Prompt for card name using AppleScript with proper button handling
            result=$(osascript -e 'display dialog "Enter a name for this card:" default answer "" buttons {"Cancel", "OK"} default button "OK"' 2>&1)
            osascript_status=$?
            
            # Check if osascript failed
            if [ $osascript_status -ne 0 ]; then
                log_message "Error: Failed to display card name dialog. Status: $osascript_status, Error: $result"
                continue
            fi
            
            log_message "Result: $result"

            # Parse the result
            button_clicked=$(echo "$result" | sed -n 's/.*button returned:\(.*\), text returned.*/\1/p' | tr -d ', ')
            card_name=$(echo "$result" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')
            
            if [ "$button_clicked" = "Cancel" ]; then
                log_message "User canceled card name dialog"
                continue
            fi
            
            if [ -n "$card_name" ]; then
                log_message "Card name entered: $card_name"
                # Launch progress app with card name as additional parameter
                launch_progress_app "offload" "$dropped_item" "$card_name"
            else
                log_message "No card name entered, skipping offload"
            fi
        else
            log_message "Dropped item is not a directory, skipping: $dropped_item"
        fi
    done
    
    exit 0
fi

# Parse arguments
while [[ "$1" != "" ]]; do
  log_message "Processing argument: '$1'"
  case $1 in
    # Mode flags
    -navbar)
      navbar=true
      ;;
    -progressbar)
      progressbar=true
      ;;
    -droplet)
      droplet=true
      ;;
    --silent)
      SILENT_MODE=true
      ;;
    --debug)
      DEBUG_MODE=true
      ;;
      
    # Progress bar operations (when launched from status menu)
    checkout|checkin|checkpoint)
      if [ "$progressbar" = true ]; then
        script="$1"
        shift
        # Single parameter operations
        parameter="$1"
        break
      fi
      ;;
    offload|verify_external)
      if [ "$progressbar" = true ]; then
        script="$1"
        shift
        # Multiple parameter operations - join with pipes
        parameter="$(printf "%s|" "$@" | sed 's/|$//')"
        break
      fi
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
      
    Remove\ \"*from\ cache)
      repo_name=$(echo "$1" | sed -n 's/^Remove "\([^"]*\)".*/\1/p')
      script="cleanup_ui"
      parameter="remove|$repo_name"
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
      
    # Checkout operations (from submenus) - handle both formats
    "Checkout "*|" Checkout "*)
      log_message "(CHECKOUT FROM SUBMENU)"
      script="checkout"
      parameter=$(echo "$1" | sed 's/^ *Checkout //' | tr -d '"')
      log_message "Extracted parameter: '$parameter'"
      ;;
      
    # Check in operations (legacy format)
    " Checkout "*)
      script="checkout"
      parameter=$(echo "$1" | sed 's/ Checkout //')
      ;;


    # Checkout operations
    "Check Out Another Project")
      script="checkout"
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
      
    # Open operations
    "Open "*)
      script="open"
      parameter=$(echo "$1" | sed 's/^Open //' | tr -d '"')
      log_message "Extracted open parameter: '$parameter'"
      ;;
      
    # New Project creation from submenu
    "New Project...")
      script="checkout"
      parameter="NEW"
      ;;
      
    # Setup menu operations
    "Set Server Address")
      script="setup_ui"
      parameter="Set Server Address"
      ;;
    "Set Server Port")
      script="setup_ui"
      parameter="Set Server Port"
      ;;
    "Set Server Path")
      script="setup_ui"
      parameter="Set Server Path"
      ;;
    "Set Checked Out Folder")
      script="setup_ui"
      parameter="Set Checked Out Folder"
      ;;
    "Set Checked In Folder")
      script="setup_ui"
      parameter="Set Checked In Folder"
      ;;
      
    # Offload menu operations
    "Set Destination")
      script="offload_ui"
      parameter="set_destination"
      ;;
    "Set Project Shortname")
      script="offload_ui"
      parameter="set_project_shortname"
      ;;
    "Video"|"✓ Video")
      script="offload_ui"
      parameter="set_type|video"
      ;;
    "Audio"|"✓ Audio")
      script="offload_ui"
      parameter="set_type|audio"
      ;;
    "Photo"|"✓ Photo")
      script="offload_ui"
      parameter="set_type|photo"
      ;;
    "Maintain Folder Structure"|"✓ Maintain Folder Structure")
      script="offload_ui"
      parameter="set_type|maintain"
      ;;
    "Offload")
      script="offload_ui"
      parameter="launch_droplet"
      ;;
    "Verify External Card")
      script="offload_ui"
      parameter="verify_external"
      ;;
            
    # Default case for direct script/parameter pairs and quoted project names
    *)
      if [ -z "$script" ]; then
        script=$1
      elif [ -z "$parameter" ]; then
        # If parameter is quoted, strip quotes
        parameter=$(echo "$1" | sed 's/^"//;s/"$//')
      fi
      ;;
  esac
  shift
done

# Enable auto checkpoint and cleanup worker only in statusbar mode (after argument parsing)
enable_auto_checkpoint
enable_cleanup_worker

# Log the final script and parameter values
log_message "Script: $script"
log_message "Parameter: $parameter"

# Execute the requested script if one was specified
if [ -n "$script" ]; then
  case $script in
    "checkin")
      log_message "preparing for checkin script"
      log_message "Parameter value: '$parameter'"
      log_message "Progressbar mode: $progressbar"

      if [ "$progressbar" = true ]; then
        log_message "Running checkin in progressbar mode for: $parameter"
        checkin "$parameter" || handle_error "Check-in operation failed"
      else
        log_message "Launching progress app for checkin: $parameter"
        launch_progress_app "checkin" "$parameter" ""
      fi
      ;;
    "checkout")
      log_message "preparing for checkout script"
      log_message "Parameter value: '$parameter'"
      log_message "Progressbar mode: $progressbar"

      if [ "$parameter" = "NEW" ]; then
        log_message "Creating new project"
        # Prompt for new repo name using AppleScript
        new_repo_name=$(osascript -e 'display dialog "Enter the name of the new repository:" default answer ""' -e 'text returned of result')
        if [ -n "$new_repo_name" ]; then
          if [ "$progressbar" = true ]; then
            log_message "Running checkout in progressbar mode"
            checkout "$new_repo_name" || handle_error "Check-out operation failed"
          else
            log_message "Launching progress app for new project"
            launch_progress_app "checkout" "$new_repo_name" ""
          fi
        fi
      else
        if [ "$progressbar" = true ]; then
          log_message "Running checkout in progressbar mode for: $parameter"
          checkout "$parameter" || handle_error "Check-out operation failed"
        else
          log_message "Launching progress app for: $parameter"
          launch_progress_app "checkout" "$parameter" ""
        fi
      fi
      ;;
    "checkpoint")
      checkpoint "$parameter" || handle_error "Checkpoint operation failed"
      ;;
    "checkpointall") 
      checkpoint_all || handle_error "Checkpoint all operation failed"
      ;;
    "cleanup_check")
      cleanup_check || handle_error "Cleanup check operation failed"
      ;;
    "setup"|"Setup")
      setup "$parameter" || handle_error "Setup operation failed"
      ;;
    "Enable Offload")
      set_offload_enabled "true" || handle_error "Failed to enable offload"
      ;;
    "Disable Offload")
      set_offload_enabled "false" || handle_error "Failed to disable offload"
      ;;
    "open")
      log_message "Attempting to open $CHECKEDOUT_FOLDER/$parameter"
      if ! repo_exists "$parameter" "$CHECKEDOUT_FOLDER"; then
        handle_error "Project directory not found: $parameter"
      else
        # Set selected_repo for the open_fcp_or_directory function
        selected_repo="$parameter"
        open_fcp_or_directory
      fi
      ;;
    "offload")
      log_message "preparing for offload script"
      log_message "Parameter value: '$parameter'"
      log_message "Card name: '$CARD_NAME'"
      
      if [ "$progressbar" = true ]; then
        log_message "Running offload in progressbar mode"
        
        # For droplet calls, the parameter is the input path and CARD_NAME is the card name
        if [ -n "$parameter" ] && [ -n "$CARD_NAME" ]; then
          log_message "Droplet mode: input_path='$parameter', card_name='$CARD_NAME'"
          run_offload_with_progress "$parameter" "$CARD_NAME" || handle_error "Offload operation failed"
        else
          # For other offload calls, parse the parameter as pipe-separated values
          if [ -n "$parameter" ]; then
            IFS='|' read -r input_path output_path project_shortname source_name type <<< "$parameter"
            
            # If source_name is empty, use the card name from CARD_NAME
            if [ -z "$source_name" ] && [ -n "$CARD_NAME" ]; then
              source_name="$CARD_NAME"
              log_message "Using card name as source name: $source_name"
            fi
            
            # For droplet calls to progress app, the parameter might be "input_path|card_name"
            # Check if we have exactly 2 parts and the second looks like a card name (not a path)
            local parts=($(echo "$parameter" | tr '|' '\n'))
            if [ ${#parts[@]} -eq 2 ] && [[ ! "${parts[1]}" =~ ^/ ]]; then
              log_message "Detected droplet format: input_path='${parts[0]}', card_name='${parts[1]}'"
              run_offload_with_progress "${parts[0]}" "${parts[1]}" || handle_error "Offload operation failed"
            else
              run_offload_with_progress "$input_path" "$source_name" || handle_error "Offload operation failed"
            fi
          else
            handle_error "Offload requires parameters: input_path|output_path|project_shortname|source_name|type"
          fi
        fi
      else
        # Parse offload parameters (input_path|output_path|project_shortname|source_name|type)
        if [ -n "$parameter" ]; then
          IFS='|' read -r input_path output_path project_shortname source_name type <<< "$parameter"
          
          # Get and increment the counter for direct offload calls
          local counter=$(increment_offload_counter)
          log_message "Using counter: $counter for direct offload"
          
          offload "$input_path" "$output_path" "$project_shortname" "$source_name" "$type" "$counter" || handle_error "Offload operation failed"
        else
          handle_error "Offload requires parameters: input_path|output_path|project_shortname|source_name|type"
        fi
      fi
      ;;
    "verify")
      log_message "preparing for verify script"
      log_message "Parameter value: '$parameter'"
      
      # Parse verify parameters (source_path|destination_path)
      if [ -n "$parameter" ]; then
        IFS='|' read -r source_path destination_path <<< "$parameter"
        verify "$source_path" "$destination_path" || handle_error "Verify operation failed"
      else
        handle_error "Verify requires parameters: source_path|destination_path"
      fi
      ;;
    "verify_external")
      log_message "preparing for external verify script"
      log_message "Parameter value: '$parameter'"
      
      # Parse external verify parameters (source_path|destination_path)
      if [ -n "$parameter" ]; then
        IFS='|' read -r source_path destination_path <<< "$parameter"
        
        if [ "$progressbar" = true ]; then
          log_message "Running external verify in progressbar mode"
          run_verify_external_with_progress "$source_path" "$destination_path" || handle_error "External verify operation failed"
        else
          verify_external_source "$source_path" "$destination_path" || handle_error "External verify operation failed"
        fi
      else
        handle_error "External verify requires parameters: source_path|destination_path"
      fi
      ;;
    "offload_ui")
      log_message "preparing for offload UI script"
      log_message "Parameter value: '$parameter'"
      
      # Parse offload UI parameters
      if [ -n "$parameter" ]; then
        IFS='|' read -r action type <<< "$parameter"
        case $action in
          "set_destination")
            set_offload_destination || handle_error "Failed to set destination"
            ;;
          "set_project_shortname")
            prompt_project_shortname || handle_error "Failed to set project shortname"
            ;;
          "set_type")
            set_offload_type "$type" || handle_error "Failed to set type"
            ;;
          "launch_droplet")
            launch_offload_droplet || handle_error "Failed to launch droplet"
            ;;
          "verify_external")
            launch_external_verification || handle_error "Failed to launch external verification"
            ;;
          *)
            handle_error "Unknown offload UI action: $action"
            ;;
        esac
      else
        handle_error "Offload UI requires parameters: action|type"
      fi
      ;;
    "cleanup_ui")
      log_message "preparing for cleanup UI script"
      log_message "Parameter value: '$parameter'"
      
      # Parse cleanup UI parameters
      if [ -n "$parameter" ]; then
        IFS='|' read -r action repo_name <<< "$parameter"
        case $action in
          "remove")
            prompt_remove_repository "$repo_name" || handle_error "Failed to remove repository"
            ;;
          *)
            handle_error "Unknown cleanup UI action: $action"
            ;;
        esac
      else
        handle_error "Cleanup UI requires parameters: action|repo_name"
      fi
      ;;
    "setup_ui")
      log_message "preparing for setup UI script"
      log_message "Parameter value: '$parameter'"
      
      # Parse setup UI parameters
      if [ -n "$parameter" ]; then
        handle_setup_menu "$parameter" || handle_error "Failed to handle setup menu"
      else
        handle_error "Setup UI requires parameters: menu_item"
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
                echo "SUBMENU|$repo_name|DISABLED|Last Autosave: $last_checkpoint|Open \"$repo_name\"|Check In \"$repo_name\""
            else
                echo "SUBMENU|$repo_name|Open \"$repo_name\"|Check In \"$repo_name\""
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
            submenu_items="$submenu_items Checkout \"$project\""
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
    
    # Add setup submenu
    display_setup_submenu
    
    # Remove offload toggle from here (now in setup submenu)
    
    # Add cleanup submenu at the top (if there are removable repositories)
    if has_removable_repos; then
        display_cleanup_submenu
    fi
    
    # Add offload submenu at the bottom
    display_offload_submenu
}

# Handle navbar mode display
if $navbar; then
    display_navbar_menu
    exit 0
fi

