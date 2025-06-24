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
    
    # Check if all parameters are provided
    if [ -z "$input_path" ] || [ -z "$output_path" ] || [ -z "$project_shortname" ] || [ -z "$source_name" ] || [ -z "$type" ]; then
        handle_error "Usage: offload <input_path> <output_path> <project_shortname> <source_name> <type>"
    fi
    
    # Validate input path exists
    if [ ! -d "$input_path" ]; then
        handle_error "Input path does not exist: $input_path"
    fi
    
    # Validate type
    if ! validate_offload_type "$type"; then
        handle_error "Invalid type. Must be: video/v, audio/a, photo/p, maintain/m"
    fi
    
    # Create output directory if it doesn't exist
    if [ ! -d "$output_path" ]; then
        log_message "Creating output directory: $output_path"
        show_details "Creating output directory..."
        mkdir -p "$output_path" || handle_error "Failed to create output directory: $output_path"
        show_details "Output directory created successfully"
    fi
    
    log_message "Parameters validated successfully"
} 