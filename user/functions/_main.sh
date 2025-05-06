log_message "-----   UNFLAB MAIN LOOP STARTED   -----"

navbar=false
script=""
parameter=""

enable_auto_checkpoint


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
      log_message "(NAVBAR MODE)"
      ;;
    fcpgit://*)
      log_message "(LAUNCHED VIA URL)"
      parse_url "$1"
      ;;
    checkpointall)
      log_message "(CHECKPOINTALL)"
      script="checkpointall"
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
    "checkpointall") 
      checkpoint_all
      ;;
    "setup")
      setup "$parameter"
      ;;
    "open")
      log_message "Attempting to open $CHECKEDOUT_FOLDER/$parameter"
      open "$CHECKEDOUT_FOLDER/$parameter"
      ;;
    *)
      echo "Unknown script: $script"
      ;;
  esac

fi

if $NAVBAR_MODE; then

    # Get checked out projects...
    if [ -d "$CHECKEDOUT_FOLDER" ]; then
        folders=("$CHECKEDOUT_FOLDER"/*)

        # Check if there are any repositories
        if [ ${#folders[@]} -eq 1 ] && [ ! -e "${folders[0]}" ]; then
            echo "(You do not currently have any projects checked out)"
        else
            for i in "${!folders[@]}"; do
                folder_name=$(basename "${folders[$i]}")

                # Determine the path to the .CHECKEDOUT file
                CHECKEDOUT_FILE="${folders[$i]}/.CHECKEDOUT"
                
                # Output action and folder name together
                echo "\"$folder_name\""

                # Read the LAST_CHECKPOINT value from the .CHECKEDOUT file
                #if [ -f "$CHECKEDOUT_FILE" ]; then
                    # last_checkpoint=$(grep 'LAST_COMMIT=' "$CHECKEDOUT_FILE" | cut -d '=' -f 2)
                    # Output project information along with the last checkpoint time
                    #echo " ↳ Last Checkpoint: $last_checkpoint"

                # else
                    # last_checkpoint="No checkpoint available"
                #fi

                echo " ↳ Check In \"$folder_name\""
                echo " ↳ Go To \"$folder_name\""
                #echo " ↳ Quick Save \"$folder_name\""

            done
        fi
    else
        echo "(You do not currently have any projects checked out)"
    fi
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

