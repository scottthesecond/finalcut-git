
navbar=false
script=""
parameter=""

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
      ;;
    fcpgit://*)
      parse_url "$1"
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
    "Setup")
      script="setup"
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

log_message "Navbar: $navbar"
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
    "setup")
      setup "$parameter"
      ;;
    "open")
      selected_repo="$parameter"
      log_message "Attempting to open $CHECKEDOUT_FOLDER/$parameter"
      open_fcp_or_directory
      ;;
    *)
      echo "Unknown script: $script"
      ;;
  esac
fi

if $NAVBAR_MODE; then

    # Get checked out projects...
    folders=("$CHECKEDOUT_FOLDER"/*)

    # Check if there are any repositories
    if [ "${folders[0]}" = "$CHECKEDOUT_FOLDER/*" ]; then
        echo "No projects are checked out."
    else
        for i in "${!folders[@]}"; do
            folder_name=$(basename "${folders[$i]}")
            # Output action and folder name together
            echo "\"$folder_name\""
            echo " ↳ Check In \"$folder_name\""
            #echo " ↳ Go To \"$folder_name\""
            echo " ↳ Quick Save \"$folder_name\""

        done
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