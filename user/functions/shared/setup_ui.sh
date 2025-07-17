#!/bin/bash

# Setup UI functions

# Function to get current server address
get_server_address() {
    if [ -n "$SERVER_ADDRESS" ]; then
        echo "$SERVER_ADDRESS"
    else
        echo "Not set"
    fi
}

# Function to get current server port
get_server_port() {
    if [ -n "$SERVER_PORT" ]; then
        echo "$SERVER_PORT"
    else
        echo "22"
    fi
}

# Function to get current server path
get_server_path() {
    if [ -n "$SERVER_PATH" ]; then
        echo "$SERVER_PATH"
    else
        echo "~/repositories"
    fi
}

# Function to get current checked out folder
get_checkedout_folder() {
    echo "$CHECKEDOUT_FOLDER"
}

# Function to get current checked in folder
get_checkedin_folder() {
    echo "$CHECKEDIN_FOLDER"
}

# Function to set server address
set_server_address() {
    local address="$1"
    if [ -n "$address" ]; then
        # Create config file if it doesn't exist
        if [ ! -f "$CONFIG_FILE" ]; then
            touch "$CONFIG_FILE"
        fi
        
        # Remove existing config line if it exists
        if grep -q "^SERVER_ADDRESS=" "$CONFIG_FILE"; then
            sed -i '' "/^SERVER_ADDRESS=/d" "$CONFIG_FILE"
        fi
        
        # Add new config line
        echo "SERVER_ADDRESS=$address" >> "$CONFIG_FILE"
        
        log_message "Set server address: $address"
        echo "Server address set to: $address"
    else
        echo "No address provided"
    fi
}

# Function to set server port
set_server_port() {
    local port="$1"
    if [ -n "$port" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
        # Create config file if it doesn't exist
        if [ ! -f "$CONFIG_FILE" ]; then
            touch "$CONFIG_FILE"
        fi
        
        # Remove existing config line if it exists
        if grep -q "^SERVER_PORT=" "$CONFIG_FILE"; then
            sed -i '' "/^SERVER_PORT=/d" "$CONFIG_FILE"
        fi
        
        # Add new config line
        echo "SERVER_PORT=$port" >> "$CONFIG_FILE"
        
        log_message "Set server port: $port"
        echo "Server port set to: $port"
    else
        echo "Invalid port: $port"
    fi
}

# Function to set server path
set_server_path() {
    local path="$1"
    if [ -n "$path" ]; then
        # Create config file if it doesn't exist
        if [ ! -f "$CONFIG_FILE" ]; then
            touch "$CONFIG_FILE"
        fi
        
        # Remove existing config line if it exists
        if grep -q "^SERVER_PATH=" "$CONFIG_FILE"; then
            sed -i '' "/^SERVER_PATH=/d" "$CONFIG_FILE"
        fi
        
        # Add new config line (quoted to handle tilde)
        echo "SERVER_PATH='$path'" >> "$CONFIG_FILE"
        
        log_message "Set server path: $path"
        echo "Server path set to: $path"
    else
        echo "No path provided"
    fi
}

# Function to prompt for server address
prompt_server_address() {
    local current_address=$(get_server_address)
    local new_address=$(osascript <<EOF
display dialog "Enter server address:" default answer "$current_address"
text returned of result
EOF
)
    
    if [ -n "$new_address" ]; then
        set_server_address "$new_address"
    else
        echo "No address entered"
    fi
}

# Function to prompt for server port
prompt_server_port() {
    local current_port=$(get_server_port)
    local new_port=$(osascript <<EOF
display dialog "Enter server port:" default answer "$current_port"
text returned of result
EOF
)
    
    if [ -n "$new_port" ]; then
        set_server_port "$new_port"
    else
        echo "No port entered"
    fi
}

# Function to prompt for server path
prompt_server_path() {
    local current_path=$(get_server_path)
    local new_path=$(osascript <<EOF
display dialog "Enter server path:" default answer "$current_path"
text returned of result
EOF
)
    
    if [ -n "$new_path" ]; then
        set_server_path "$new_path"
    else
        echo "No path entered"
    fi
}

# Function to prompt for checked out folder
prompt_checkedout_folder() {
    local current_folder=$(get_checkedout_folder)
    local new_folder=$(osascript <<EOF
display dialog "Enter checked out folder path:" default answer "$current_folder"
text returned of result
EOF
)
    
    if [ -n "$new_folder" ]; then
        # Update the CHECKEDOUT_FOLDER variable
        CHECKEDOUT_FOLDER="$new_folder"
        
        # Create the folder if it doesn't exist
        mkdir -p "$new_folder"
        
        log_message "Set checked out folder: $new_folder"
        echo "Checked out folder set to: $new_folder"
    else
        echo "No folder entered"
    fi
}

# Function to prompt for checked in folder
prompt_checkedin_folder() {
    local current_folder=$(get_checkedin_folder)
    local new_folder=$(osascript <<EOF
display dialog "Enter checked in folder path:" default answer "$current_folder"
text returned of result
EOF
)
    
    if [ -n "$new_folder" ]; then
        # Update the CHECKEDIN_FOLDER variable
        CHECKEDIN_FOLDER="$new_folder"
        
        # Create the folder if it doesn't exist
        mkdir -p "$new_folder"
        
        log_message "Set checked in folder: $new_folder"
        echo "Checked in folder set to: $new_folder"
    else
        echo "No folder entered"
    fi
}

# Function to display setup submenu
display_setup_submenu() {
    local current_address=$(get_server_address)
    local current_port=$(get_server_port)
    local current_path=$(get_server_path)
    local offload_enabled=$(get_offload_enabled)
    
    # Build submenu items string
    local submenu_items=""
    
    # Server address section
    submenu_items="DISABLED|Server: $current_address"
    submenu_items="$submenu_items|Set Server Address"
    submenu_items="$submenu_items|----"
    
    # Server port section
    submenu_items="$submenu_items|DISABLED|Port: $current_port"
    submenu_items="$submenu_items|Set Server Port"
    submenu_items="$submenu_items|----"
    
    # Server path section
    submenu_items="$submenu_items|DISABLED|Path: $current_path"
    submenu_items="$submenu_items|Set Server Path"
    submenu_items="$submenu_items|----"
    
    # Offload toggle
    if [ "$offload_enabled" = "true" ]; then
        submenu_items="$submenu_items|Disable Offload"
    else
        submenu_items="$submenu_items|Enable Offload"
    fi
    
    # Output the submenu in Platypus format
    echo "SUBMENU|Setup|$submenu_items"
}

# Function to handle setup menu selection
handle_setup_menu() {
    local menu_item="$1"
    
    case "$menu_item" in
        "Set Server Address")
            prompt_server_address
            ;;
        "Set Server Port")
            prompt_server_port
            ;;
        "Set Server Path")
            prompt_server_path
            ;;
        "Enable Offload")
            set_offload_enabled "true"
            ;;
        "Disable Offload")
            set_offload_enabled "false"
            ;;
        *)
            echo "Unknown setup menu item: $menu_item"
            ;;
    esac
} 