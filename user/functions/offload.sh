#!/bin/bash

# Offload script for SD card footage
# Usage: offload <input_path> <output_path> <project_shortname> <source_name> <type>

# Function to validate input parameters
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
    case "$type" in
        video|v|audio|a|photo|p|maintain|m)
            ;;
        *)
            handle_error "Invalid type. Must be: video/v, audio/a, photo/p, maintain/m"
            ;;
    esac
    
    # Create output directory if it doesn't exist
    if [ ! -d "$output_path" ]; then
        log_message "Creating output directory: $output_path"
        mkdir -p "$output_path" || handle_error "Failed to create output directory: $output_path"
    fi
    
    log_message "Parameters validated successfully"
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

# Function to scan input directory and build file list
scan_input_directory() {
    local input_path="$1"
    local project_shortname="$2"
    local source_name="$3"
    local type="$4"
    local offload_file="$5"
    
    local type_prefix=$(get_type_prefix "$type")
    local file_counter=1
    
    log_message "Scanning input directory: $input_path"
    
    # Find all files recursively and process them
    while IFS= read -r file_path; do
        # Skip the .offload file itself and any backup files
        if [[ "$file_path" == *".offload"* ]]; then
            continue
        fi
        
        # Get file extension
        local extension="${file_path##*.}"
        
        # Generate new filename
        local new_filename="${type_prefix}$(printf "%04d" $file_counter).${project_shortname}.${source_name}.${file_counter}.${extension}"
        
        # Determine destination path based on type
        local dest_path
        if [ "$type" = "maintain" ] || [ "$type" = "m" ]; then
            # Maintain folder structure
            local relative_path="${file_path#$input_path/}"
            local dest_dir="$output_path/$(dirname "$relative_path")"
            mkdir -p "$dest_dir"
            dest_path="$dest_dir/$new_filename"
        else
            # Flat structure
            dest_path="$output_path/$new_filename"
        fi
        
        # Add to offload file
        echo "$file_path|$dest_path|$new_filename|queued" >> "$offload_file"
        
        log_message "Queued: $file_path -> $dest_path"
        ((file_counter++))
    done < <(find "$input_path" -type f)
    
    log_message "Scan complete. Found $((file_counter-1)) files to offload"
}

# Function to copy files and update status
copy_files() {
    local offload_file="$1"
    local output_path="$2"
    local total_files=$(wc -l < "$offload_file")
    local current_file=0
    
    # Create destination offload file for filename mappings
    local dest_offload_file="$output_path/.offload"
    > "$dest_offload_file"
    
    log_message "Starting file copy process for $total_files files"
    
    while IFS='|' read -r source_path dest_path new_filename status; do
        ((current_file++))
        
        if [ "$status" = "queued" ]; then
            log_message "Copying file $current_file/$total_files: $source_path"
            
            # Copy the file
            if cp "$source_path" "$dest_path"; then
                # Update status to unverified
                sed -i '' "${current_file}s/queued$/unverified/" "$offload_file"
                
                # Add mapping to destination offload file
                echo "$new_filename|$(basename "$source_path")" >> "$dest_offload_file"
                
                log_message "Successfully copied: $new_filename"
            else
                log_message "ERROR: Failed to copy $source_path"
                # Update status to failed
                sed -i '' "${current_file}s/queued$/failed/" "$offload_file"
            fi
        fi
    done < "$offload_file"
    
    log_message "File copy process complete"
    log_message "Created destination mapping file: $dest_offload_file"
}

# Main offload function
offload() {
    local input_path="$1"
    local output_path="$2"
    local project_shortname="$3"
    local source_name="$4"
    local type="$5"
    
    log_message "Starting offload process"
    log_message "Input: $input_path"
    log_message "Output: $output_path"
    log_message "Project: $project_shortname"
    log_message "Source: $source_name"
    log_message "Type: $type"
    
    # Validate parameters
    validate_offload_params "$input_path" "$output_path" "$project_shortname" "$source_name" "$type"
    
    # Create offload tracking file
    local offload_file="$input_path/.offload"
    if [ -f "$offload_file" ]; then
        log_message "Warning: .offload file already exists. Backing up to .offload.backup"
        cp "$offload_file" "$offload_file.backup"
    fi
    
    # Clear/create offload file
    > "$offload_file"
    log_message "Created offload tracking file: $offload_file"
    
    # Scan input directory and build file list
    scan_input_directory "$input_path" "$project_shortname" "$source_name" "$type" "$offload_file"
    
    # Copy files and update status
    copy_files "$offload_file" "$output_path"
    
    # Display summary
    local total_files=$(wc -l < "$offload_file")
    local unverified_count=$(grep -c "unverified" "$offload_file" 2>/dev/null || echo "0")
    local failed_count=$(grep -c "failed" "$offload_file" 2>/dev/null || echo "0")
    
    log_message "Offload complete!"
    log_message "Total files: $total_files"
    log_message "Successfully copied: $unverified_count"
    if [ "$failed_count" -gt 0 ] 2>/dev/null; then
        log_message "Failed: $failed_count"
    fi
    
    echo "Offload complete! $unverified_count files copied to $output_path"
} 