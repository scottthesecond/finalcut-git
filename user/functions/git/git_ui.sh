#!/bin/bash

# Git UI functions

# Function to get git configuration
get_git_config() {
    local config_key="$1"
    if [ -f "$CONFIG_FILE" ]; then
        # Use head -1 to get only the first match if there are multiple lines
        grep "^GIT_${config_key}=" "$CONFIG_FILE" | head -1 | cut -d'=' -f2- | tr -d '"'
    else
        echo ""
    fi
}

# Function to set git configuration
set_git_config() {
    local config_key="$1"
    local config_value="$2"
    
    # Create config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        touch "$CONFIG_FILE"
    fi
    
    # Remove existing config line if it exists
    if grep -q "^GIT_${config_key}=" "$CONFIG_FILE"; then
        sed -i '' "/^GIT_${config_key}=/d" "$CONFIG_FILE"
    fi
    
    # Add new config line
    echo "GIT_${config_key}=\"${config_value}\"" >> "$CONFIG_FILE"
    
    log_message "Set git config: GIT_${config_key}=${config_value}"
}

# Function to initialize default git settings
initialize_git_defaults() {
    # Only initialize if config file doesn't exist or SERVER_ADDRESS is not set
    if [ ! -f "$CONFIG_FILE" ] || [ -z "$(get_git_config "SERVER_ADDRESS")" ]; then
        log_message "Initializing default git settings"
        set_git_config "SERVER_ADDRESS" ""
        set_git_config "SERVER_PORT" "22"
        set_git_config "SERVER_PATH" "~/repositories"
        
        # Also ensure the old SERVER_PATH variable is set for backwards compatibility
        if [ -f "$CONFIG_FILE" ] && ! grep -q "^SERVER_PATH=" "$CONFIG_FILE"; then
            echo "SERVER_PATH='~/repositories'" >> "$CONFIG_FILE"
            log_message "Added old SERVER_PATH for backwards compatibility"
        fi
    fi
}

# Function to get current git server address
get_git_server_address() {
    local address=$(get_git_config "SERVER_ADDRESS")
    if [ -z "$address" ]; then
        echo "Not set"
    else
        echo "$address"
    fi
}

# Function to get current git server port
get_git_server_port() {
    local port=$(get_git_config "SERVER_PORT")
    if [ -z "$port" ]; then
        echo "22"
    else
        echo "$port"
    fi
}

# Function to get current git server path
get_git_server_path() {
    local path=$(get_git_config "SERVER_PATH")
    if [ -z "$path" ]; then
        echo "~/repositories"
    else
        echo "$path"
    fi
}

# Function to set git server address
set_git_server_address() {
    local address="$1"
    if [ -n "$address" ]; then
        set_git_config "SERVER_ADDRESS" "$address"
        echo "Server address set to: $address"
    else
        echo "No address provided"
    fi
}

# Function to prompt for git server address
prompt_git_server_address() {
    local current_address=$(get_git_server_address)
    local new_address=$(osascript <<EOF
display dialog "Enter Git server address:" default answer "$current_address"
text returned of result
EOF
)
    
    if [ -n "$new_address" ]; then
        set_git_server_address "$new_address"
        echo "Server address set to: $new_address"
    else
        echo "No address entered"
    fi
}

# Function to set git server port
set_git_server_port() {
    local port="$1"
    if [ -n "$port" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
        set_git_config "SERVER_PORT" "$port"
        echo "Server port set to: $port"
    else
        echo "Invalid port: $port"
    fi
}

# Function to prompt for git server port
prompt_git_server_port() {
    local current_port=$(get_git_server_port)
    local new_port=$(osascript <<EOF
display dialog "Enter Git server port:" default answer "$current_port"
text returned of result
EOF
)
    
    if [ -n "$new_port" ]; then
        set_git_server_port "$new_port"
        echo "Server port set to: $new_port"
    else
        echo "No port entered"
    fi
}

# Function to set git server path
set_git_server_path() {
    local path="$1"
    if [ -n "$path" ]; then
        set_git_config "SERVER_PATH" "$path"
        echo "Server path set to: $path"
    else
        echo "No path provided"
    fi
}

# Function to prompt for git server path
prompt_git_server_path() {
    local current_path=$(get_git_server_path)
    local new_path=$(osascript <<EOF
display dialog "Enter Git server path:" default answer "$current_path"
text returned of result
EOF
)
    
    if [ -n "$new_path" ]; then
        set_git_server_path "$new_path"
        echo "Server path set to: $new_path"
    else
        echo "No path entered"
    fi
}

# Function to test git connectivity
test_git_connectivity() {
    local server_address=$(get_git_server_address)
    local server_port=$(get_git_server_port)
    
    if [ "$server_address" = "Not set" ]; then
        handle_error "Server address not configured. Please set the server address first."
        return 1
    fi
    
    log_message "Testing connectivity to $server_address:$server_port"
    
    # Test SSH connectivity
    if ssh -o ConnectTimeout=10 -o BatchMode=yes -p "$server_port" "$server_address" exit 2>/dev/null; then
        log_message "SSH connectivity test successful"
        echo "✓ Connected successfully to $server_address:$server_port"
    else
        log_message "SSH connectivity test failed"
        handle_error "Failed to connect to $server_address:$server_port. Please check your settings and SSH key configuration."
        return 1
    fi
}

# Function to display git submenu
display_git_submenu() {
    local current_address=$(get_git_server_address)
    local current_port=$(get_git_server_port)
    local current_path=$(get_git_server_path)
    
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
    
    # Test connectivity
    submenu_items="$submenu_items|Test Connection"
    
    # Output the submenu in Platypus format
    echo "SUBMENU|Git Settings|$submenu_items"
}

# Function to handle git menu selection
handle_git_menu() {
    local menu_item="$1"
    
    case "$menu_item" in
        "Set Server Address")
            prompt_git_server_address
            ;;
        "Set Server Port")
            prompt_git_server_port
            ;;
        "Set Server Path")
            prompt_git_server_path
            ;;
        "Test Connection")
            test_git_connectivity
            ;;
        *)
            echo "Unknown git menu item: $menu_item"
            ;;
    esac
}

# Function to validate git configuration
validate_git_config() {
    local server_address=$(get_git_server_address)
    local server_port=$(get_git_server_port)
    local server_path=$(get_git_server_path)
    
    if [ "$server_address" = "Not set" ]; then
        return 1
    fi
    
    if [ -z "$server_port" ] || ! [[ "$server_port" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if [ -z "$server_path" ]; then
        return 1
    fi
    
    return 0
}

# Function to get git configuration status
get_git_config_status() {
    if validate_git_config; then
        echo "Configured"
    else
        echo "Not configured"
    fi
} 