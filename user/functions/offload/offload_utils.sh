#!/bin/bash

# Shared utilities for offload functionality

# Function to validate offload type
validate_offload_type() {
    local type="$1"
    case "$type" in
        video|v|audio|a|photo|p|maintain|m)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to get type prefix
get_type_prefix() {
    local type="$1"
    case "$type" in
        video|v) echo "v" ;;
        audio|a) echo "a" ;;
        photo|p) echo "p" ;;
        maintain|m) echo "m" ;;
        *) echo "v" ;; # Default to video
    esac
}

# Function to sanitize source name
sanitize_source_name() {
    local input_name="$1"
    local fallback_path="$2"
    
    local source_name
    if [ -n "$input_name" ]; then
        source_name=$(echo "$input_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
        log_message "Using provided source name: $input_name (sanitized: $source_name)"
    else
        source_name=$(basename "$fallback_path" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
        log_message "Generated source name from input path: $source_name"
    fi
    
    if [ -z "$source_name" ]; then
        source_name="source"
    fi
    
    echo "$source_name"
}

# Function to validate offload parameters
validate_offload_params() {
    local input_path="$1"
    local output_path="$2"
    local project_shortname="$3"
    local source_name="$4"
    local type="$5"
    
    # Validate input path
    if [ -z "$input_path" ] || [ ! -d "$input_path" ]; then
        log_message "Error: Invalid input path: $input_path"
        return 1
    fi
    
    # Validate output path
    if [ -z "$output_path" ]; then
        log_message "Error: Output path is required"
        return 1
    fi
    
    # Validate project shortname
    if [ -z "$project_shortname" ]; then
        log_message "Error: Project shortname is required"
        return 1
    fi
    
    # Validate source name
    if [ -z "$source_name" ]; then
        log_message "Error: Source name is required"
        return 1
    fi
    
    # Validate type
    if ! validate_offload_type "$type"; then
        log_message "Error: Invalid offload type: $type"
        return 1
    fi
    
    return 0
}

# Function to get connected SD cards and external devices
get_connected_devices() {
    local devices=()
    
    # Get all mounted volumes using diskutil
    while IFS= read -r line; do
        local device_path=""
        local volume_name=""
        local volume_path=""
        local device_type=""
        local device_location=""
        local protocol=""
        
        device_path=$(echo "$line" | grep -o '/dev/disk[0-9]*' | head -1)
        
        if [ -n "$device_path" ]; then
            local device_info=$(diskutil info "$device_path" 2>/dev/null)
            if [ -n "$device_info" ]; then
                volume_name=$(echo "$device_info" | grep "Volume Name:" | cut -d: -f2 | xargs)
                volume_path=$(echo "$device_info" | grep "Mount Point:" | cut -d: -f2 | xargs)
                device_type=$(echo "$device_info" | grep "Media Type:" | cut -d: -f2 | xargs)
                device_location=$(echo "$device_info" | grep "Device Location:" | cut -d: -f2 | xargs)
                protocol=$(echo "$device_info" | grep "Protocol:" | cut -d: -f2 | xargs)
                
                # Only include if it's mounted and has a valid path
                if [ -n "$volume_path" ] && [ -d "$volume_path" ]; then
                    # Hide internal drives
                    if [[ "$device_location" == "Internal" ]] || [[ "$device_type" == "Internal" ]] || [[ "$protocol" == "Apple_APFS" ]] || [[ "$volume_name" =~ ^Macintosh\ HD ]] || [[ "$volume_name" =~ ^Sonoma ]] || [[ "$volume_name" =~ ^Data$ ]]; then
                        continue
                    fi
                    # Hide network shares
                    if [[ "$device_type" == "Network" ]] || [[ "$protocol" == "Network" ]]; then
                        continue
                    fi
                    # Skip system volumes
                    if [[ "$volume_path" == "/" ]] || [[ "$volume_path" == "/System"* ]] || [[ "$volume_path" == "/Applications"* ]] || [[ "$volume_path" == "/Users"* ]]; then
                        continue
                    fi
                    # Create a descriptive name
                    local display_name="$volume_name"
                    if [ -n "$device_type" ]; then
                        display_name="$volume_name ($device_type)"
                    fi
                    devices+=("$display_name|$volume_path|$device_path")
                fi
            fi
        fi
    done < <(diskutil list | grep -E '/dev/disk[0-9]+')
    
    # Also check for any folders in /Volumes that might be external devices
    for volume in /Volumes/*; do
        if [ -d "$volume" ] && [ ! -L "$volume" ]; then
            local volume_name=$(basename "$volume")
            # Hide internal and system volumes
            if [[ "$volume_name" =~ ^Macintosh\ HD ]] || [[ "$volume_name" =~ ^Sonoma ]] || [[ "$volume_name" == ".Spotlight-V100" ]] || [[ "$volume_name" == ".Trashes" ]] || [[ "$volume_name" == ".fseventsd" ]] || [[ "$volume_name" == "Data" ]]; then
                continue
            fi
            # Hide network shares (mounted with : in path or .afpvolume/.smbvolume marker)
            if [[ "$volume" == *":"* ]] || [ -f "$volume/.afpvolume" ] || [ -f "$volume/.smbvolume" ]; then
                continue
            fi
            # Check if this volume is already in our list
            local already_listed=false
            for device in "${devices[@]}"; do
                IFS='|' read -r display_name volume_path device_path <<< "$device"
                if [ "$volume_path" = "$volume" ]; then
                    already_listed=true
                    break
                fi
            done
            if [ "$already_listed" = false ]; then
                devices+=("$volume_name (External Device)|$volume|")
            fi
        fi
    done
    printf '%s\n' "${devices[@]}"
}

# Function to select a connected device using AppleScript, with a custom prompt
select_connected_device() {
    local prompt_text="$1"
    local devices=()
    while IFS= read -r device; do
        devices+=("$device")
    done < <(get_connected_devices)
    
    if [ ${#devices[@]} -eq 0 ]; then
        log_message "No external devices found"
        echo ""
        return 1
    fi
    
    # Create an AppleScript list with device names, each quoted
    local device_list=""
    for device in "${devices[@]}"; do
        IFS='|' read -r display_name volume_path device_path <<< "$device"
        display_name_escaped=$(echo "$display_name" | sed 's/"/\\"/g')
        if [ -n "$device_list" ]; then
            device_list="$device_list, \"$display_name_escaped\""
        else
            device_list="\"$display_name_escaped\""
        fi
    done
    
    # Use AppleScript to display a dialog with the device options
    local selected_device=$(osascript -e "choose from list {${device_list}} with prompt \"${prompt_text}\"")
    
    if [ "$selected_device" = "false" ]; then
        log_message "User canceled device selection"
        echo ""
        return 1
    fi
    
    for device in "${devices[@]}"; do
        IFS='|' read -r display_name volume_path device_path <<< "$device"
        if [ "$display_name" = "$selected_device" ]; then
            log_message "Selected device: $display_name -> $volume_path"
            echo "$volume_path"
            return 0
        fi
    done
    log_message "Selected device not found in list"
    echo ""
    return 1
} 