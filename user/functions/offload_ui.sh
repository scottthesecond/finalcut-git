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
    local type=$(get_offload_config "TYPE")
    if [ -z "$type" ]; then
        echo "video"
    else
        echo "$type"
    fi
}

# Function to set offload destination using folder picker
set_offload_destination() {
    local selected_path=$(osascript -e 'tell application "System Events"
        set theFolder to choose folder with prompt "Select offload destination folder:"
        return POSIX path of theFolder
    end tell' 2>/dev/null)
    
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
    case "$type" in
        video|audio|photo|maintain)
            set_offload_config "TYPE" "$type"
            echo "Offload type set to: $type"
            ;;
        *)
            echo "Invalid type: $type"
            ;;
    esac
}

# Function to display offload submenu
display_offload_submenu() {
    local current_dest=$(get_offload_destination)
    local current_type=$(get_offload_type)
    
    # Build submenu items string
    local submenu_items=""
    
    # Destination section
    submenu_items="DISABLED|Destination: $current_dest"
    submenu_items="$submenu_items|Set Destination"
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
    local type=$(get_offload_config "TYPE")
    
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
    local dest=$(get_offload_config "DESTINATION")
    local type=$(get_offload_config "TYPE")
    
    if [ -z "$dest" ]; then
        handle_error "Offload destination not set"
    fi
    
    # Generate project shortname and source name from input path
    local project_shortname="PROJ"
    local source_name=$(basename "$input_path" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
    
    if [ -z "$source_name" ]; then
        source_name="source"
    fi
    
    log_message "Running offload in progress mode"
    log_message "Input: $input_path"
    log_message "Output: $dest"
    log_message "Type: $type"
    log_message "Project: $project_shortname"
    log_message "Source: $source_name"
    
    # Run offload
    offload "$input_path" "$dest" "$project_shortname" "$source_name" "$type" || handle_error "Offload operation failed"
    
    # Run verification
    log_message "Starting verification after offload"
    verify "$input_path" "$dest" || handle_error "Verification failed"
    
    log_message "Offload and verification complete"
    echo "Offload and verification complete!"
} 