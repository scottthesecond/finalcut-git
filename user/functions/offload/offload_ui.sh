#!/bin/bash

# Offload UI functions

# Function to get offload configuration
get_offload_config() {
    local config_key="$1"
    if [ -f "$CONFIG_FILE" ]; then
        grep "^OFFLOAD_${config_key}=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'
    else
        echo ""
    fi
}

# Function to set offload configuration
set_offload_config() {
    local config_key="$1"
    local config_value="$2"
    
    # Create config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
    fi
    
    # Remove existing config line if it exists
    if grep -q "^OFFLOAD_${config_key}=" "$CONFIG_FILE"; then
        sed -i '' "/^OFFLOAD_${config_key}=/d" "$CONFIG_FILE"
    fi
    
    # Add new config line
    echo "OFFLOAD_${config_key}=\"${config_value}\"" >> "$CONFIG_FILE"
    
    log_message "Set offload config: OFFLOAD_${config_key}=${config_value}"
}

# Function to initialize default offload settings
initialize_offload_defaults() {
    # Only initialize if config file doesn't exist or TYPE is not set
    if [ ! -f "$CONFIG_FILE" ] || [ -z "$(get_offload_config "TYPE")" ]; then
        log_message "Initializing default offload settings"
        set_offload_config "TYPE" "video"
        set_offload_config "PROJECT_SHORTNAME" "PROJ"
        set_offload_config "COUNTER" "1"
    fi
}

# Function to get current offload counter
get_offload_counter() {
    local counter=$(get_offload_config "COUNTER")
    if [ -z "$counter" ]; then
        echo "1"
    else
        echo "$counter"
    fi
}

# Function to increment offload counter
increment_offload_counter() {
    local current_counter=$(get_offload_counter)
    local new_counter=$((current_counter + 1))
    set_offload_config "COUNTER" "$new_counter" > /dev/null
    echo "$current_counter"
}

# Function to get current offload destination
get_offload_destination() {
    local dest=$(get_offload_config "DESTINATION")
    if [ -z "$dest" ]; then
        echo "Not set"
    else
        echo "$dest"
    fi
}

# Function to get current offload type
get_offload_type() {
    # Initialize defaults if needed
    initialize_offload_defaults
    
    local type=$(get_offload_config "TYPE")
    if [ -z "$type" ]; then
        echo "video"
    else
        echo "$type"
    fi
}

# Function to get current project shortname
get_project_shortname() {
    local shortname=$(get_offload_config "PROJECT_SHORTNAME")
    if [ -z "$shortname" ]; then
        echo "PROJ"
    else
        echo "$shortname"
    fi
}

# Function to set project shortname
set_project_shortname() {
    local shortname="$1"
    if [ -n "$shortname" ]; then
        set_offload_config "PROJECT_SHORTNAME" "$shortname"
        echo "Project shortname set to: $shortname"
    else
        echo "No shortname provided"
    fi
}

# Function to prompt for project shortname
prompt_project_shortname() {
    local current_shortname=$(get_project_shortname)
    local new_shortname=$(osascript <<EOF
display dialog "Enter project shortname:" default answer "$current_shortname"
text returned of result
EOF
)
    
    if [ -n "$new_shortname" ]; then
        set_project_shortname "$new_shortname"
        echo "Project shortname set to: $new_shortname"
    else
        echo "No shortname entered"
    fi
}

# Function to set offload destination using folder picker
set_offload_destination() {
    local selected_path=$(osascript <<'EOF'
set theFolder to choose folder with prompt "Select offload destination folder:"
return POSIX path of theFolder
EOF
)
    
    if [ -n "$selected_path" ]; then
        set_offload_config "DESTINATION" "$selected_path"
        echo "Destination set to: $selected_path"
    else
        echo "No destination selected"
    fi
}

# Function to set offload type
set_offload_type() {
    local type="$1"
    if validate_offload_type "$type"; then
        set_offload_config "TYPE" "$type"
        echo "Offload type set to: $type"
    else
        echo "Invalid type: $type"
    fi
}

# Function to display offload submenu
display_offload_submenu() {
    local current_dest=$(get_offload_destination)
    local current_type=$(get_offload_type)
    local current_shortname=$(get_project_shortname)
    
    # Build submenu items string
    local submenu_items=""
    
    # Destination section
    submenu_items="DISABLED|Destination: $current_dest"
    submenu_items="$submenu_items|Set Destination"
    submenu_items="$submenu_items|----"
    
    # Project shortname section
    submenu_items="$submenu_items|DISABLED|Project: $current_shortname"
    submenu_items="$submenu_items|Set Project Shortname"
    submenu_items="$submenu_items|----"
    
    # Type selection
    if [ "$current_type" = "video" ]; then
        submenu_items="$submenu_items|✓ Video"
    else
        submenu_items="$submenu_items|Video"
    fi
    
    if [ "$current_type" = "audio" ]; then
        submenu_items="$submenu_items|✓ Audio"
    else
        submenu_items="$submenu_items|Audio"
    fi
    
    if [ "$current_type" = "photo" ]; then
        submenu_items="$submenu_items|✓ Photo"
    else
        submenu_items="$submenu_items|Photo"
    fi
    
    if [ "$current_type" = "maintain" ]; then
        submenu_items="$submenu_items|✓ Maintain Folder Structure"
    else
        submenu_items="$submenu_items|Maintain Folder Structure"
    fi
    
    submenu_items="$submenu_items|----"
    submenu_items="$submenu_items|Offload"
    
    # Output the submenu in Platypus format
    echo "SUBMENU|Offload|$submenu_items"
}

# Function to handle offload menu selection
handle_offload_menu() {
    local menu_item="$1"
    
    case "$menu_item" in
        "Set Destination")
            set_offload_destination
            ;;
        "Set Project Shortname")
            prompt_project_shortname
            ;;
        "Video")
            set_offload_type "video"
            ;;
        "Audio")
            set_offload_type "audio"
            ;;
        "Photo")
            set_offload_type "photo"
            ;;
        "Maintain Folder Structure")
            set_offload_type "maintain"
            ;;
        "Offload")
            launch_offload_droplet
            ;;
        *)
            echo "Unknown offload menu item: $menu_item"
            ;;
    esac
}

# Function to launch offload droplet
launch_offload_droplet() {
    local dest=$(get_offload_config "DESTINATION")
    local type=$(get_offload_type)
    
    if [ -z "$dest" ]; then
        handle_error "Offload destination not set. Please set a destination first."
    fi
    
    # Get the path to the bundled droplet app
    local droplet_app_path="${SCRIPT_DIR}/UNFlab Offload Droplet.app"
    
    log_message "Launching offload droplet: $droplet_app_path"
    
    # Check if the app exists
    if [ -d "$droplet_app_path" ]; then
        log_message "Droplet app found at bundled location"
        open "$droplet_app_path"
        log_message "Droplet launch command completed"
    else
        log_message "Droplet app not found at bundled location, trying Applications folder"
        # Fallback: try to find it in Applications
        open -a "UNFlab Offload Droplet"
        log_message "Fallback droplet launch command completed"
    fi
}

# Function to run offload with progress bar
run_offload_with_progress() {
    local input_path="$1"
    local provided_source_name="$2"
    local base_dest=$(get_offload_config "DESTINATION")
    local type=$(get_offload_type)
    
    if [ -z "$base_dest" ]; then
        handle_error "Offload destination not set"
    fi
    
    # Generate project shortname and source name from input path
    local project_shortname=$(get_project_shortname)
    local source_name=$(sanitize_source_name "$provided_source_name" "$input_path")
    
    # Get and increment the counter
    local counter=$(increment_offload_counter)
    local type_prefix=$(get_type_prefix "$type")
    
    # Create destination folder with the new naming scheme
    local dest_folder="${type_prefix}$(printf "%04d" $counter).${project_shortname}.${source_name}"
    local full_dest_path="$base_dest/$dest_folder"
    
    log_message "Running offload in progress mode"
    log_message "Input: $input_path"
    log_message "Base Output: $base_dest"
    log_message "Destination Folder: $dest_folder"
    log_message "Full Output: $full_dest_path"
    log_message "Type: $type"
    log_message "Project: $project_shortname"
    log_message "Source: $source_name"
    log_message "Counter: $counter"
    
    # Run offload
    offload "$input_path" "$full_dest_path" "$project_shortname" "$source_name" "$type" "$counter"
    local offload_exit_code=$?
    
    # Check if offload returned early (resume, retry, or re-verify)
    if [ $offload_exit_code -eq 0 ]; then
        # Since we're not capturing output, we can't check the result message
        # The offload function will handle its own completion messages
        log_message "Offload operation completed successfully"
        return 0
    elif [ $offload_exit_code -ne 0 ]; then
        handle_error "Offload operation failed"
    fi
    
    # If we get here, it was a new offload, so run verification
    log_message "Starting verification after new offload"
    verify "$input_path" "$full_dest_path" || handle_error "Verification failed"
    
    log_message "Offload and verification complete"
    echo "Offload and verification complete!"
} 