#!/bin/bash

# Verify script for offloaded footage
# Usage: verify <source_path> [destination_path]

# Function to validate input parameters
validate_verify_params() {
    local source_path="$1"
    local destination_path="$2"
    
    # Check if source path is provided
    if [ -z "$source_path" ]; then
        handle_error "Usage: verify <source_path> [destination_path]"
    fi
    
    # Validate source path exists
    if [ ! -d "$source_path" ]; then
        handle_error "Source path does not exist: $source_path"
    fi
    
    log_message "Parameters validated successfully"
}

# Function to calculate SHA256 hash of a file
calculate_hash() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        shasum -a 256 "$file_path" | cut -d' ' -f1
    else
        echo ""
    fi
}

# Function to get file size
get_file_size() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to verify files using source .offload file
verify_with_source_offload() {
    local source_path="$1"
    local source_offload_file="$2"
    local destination_path="$3"
    
    log_message "Verifying files using source .offload file"
    
    local total_files=$(wc -l < "$source_offload_file")
    local current_file=0
    local verified_count=0
    local failed_count=0
    
    # Create or update destination .offload file for hash storage
    local dest_offload_file="$destination_path/.offload"
    local temp_dest_offload="$destination_path/.offload.tmp"
    > "$temp_dest_offload"
    
    while IFS='|' read -r source_file dest_file new_filename status; do
        ((current_file++))
        
        log_message "Verifying file $current_file/$total_files: $new_filename"
        
        # Check if source file exists
        if [ ! -f "$source_file" ]; then
            log_message "ERROR: Source file not found: $source_file"
            # Update status to failed
            sed -i '' "${current_file}s/$status$/failed/" "$source_offload_file"
            echo "$new_filename|$(basename "$source_file")|failed|0|0|" >> "$temp_dest_offload"
            ((failed_count++))
            continue
        fi
        
        # Check if destination file exists
        if [ ! -f "$dest_file" ]; then
            log_message "ERROR: Destination file not found: $dest_file"
            # Update status to failed
            sed -i '' "${current_file}s/$status$/failed/" "$source_offload_file"
            echo "$new_filename|$(basename "$source_file")|failed|0|0|" >> "$temp_dest_offload"
            ((failed_count++))
            continue
        fi
        
        # Calculate source file hash and size
        log_message "Calculating source file hash..."
        local source_hash=$(calculate_hash "$source_file")
        local source_size=$(get_file_size "$source_file")
        
        # Calculate destination file hash and size
        log_message "Calculating destination file hash..."
        local dest_hash=$(calculate_hash "$dest_file")
        local dest_size=$(get_file_size "$dest_file")
        
        # Verify sizes match
        if [ "$source_size" != "$dest_size" ]; then
            log_message "ERROR: Size mismatch for $new_filename (source: $source_size, dest: $dest_size)"
            # Update status to failed
            sed -i '' "${current_file}s/$status$/failed/" "$source_offload_file"
            echo "$new_filename|$(basename "$source_file")|failed|$source_size|$dest_size|$source_hash|$dest_hash" >> "$temp_dest_offload"
            ((failed_count++))
            continue
        fi
        
        # Verify hashes match
        if [ "$source_hash" != "$dest_hash" ]; then
            log_message "ERROR: Hash mismatch for $new_filename"
            log_message "Source hash: $source_hash"
            log_message "Dest hash: $dest_hash"
            # Update status to failed
            sed -i '' "${current_file}s/$status$/failed/" "$source_offload_file"
            echo "$new_filename|$(basename "$source_file")|failed|$source_size|$dest_size|$source_hash|$dest_hash" >> "$temp_dest_offload"
            ((failed_count++))
            continue
        fi
        
        # Update status to verified
        sed -i '' "${current_file}s/$status$/verified/" "$source_offload_file"
        echo "$new_filename|$(basename "$source_file")|verified|$source_size|$dest_size|$source_hash|$dest_hash" >> "$temp_dest_offload"
        
        log_message "✓ Verified: $new_filename (size: $source_size, hash: ${source_hash:0:8}...)"
        ((verified_count++))
        
    done < "$source_offload_file"
    
    # Replace destination .offload file with updated version
    mv "$temp_dest_offload" "$dest_offload_file"
    
    log_message "Verification complete!"
    log_message "Total files: $total_files"
    log_message "Verified: $verified_count"
    log_message "Failed: $failed_count"
    
    echo "Verification complete! $verified_count/$total_files files verified successfully."
}

# Function to verify files using destination .offload file
verify_with_destination_offload() {
    local source_path="$1"
    local destination_path="$2"
    local dest_offload_file="$3"
    
    log_message "Verifying files using destination .offload file"
    
    local total_files=$(wc -l < "$dest_offload_file")
    local current_file=0
    local verified_count=0
    local failed_count=0
    
    # Create temporary file for updated destination .offload
    local temp_dest_offload="$destination_path/.offload.tmp"
    > "$temp_dest_offload"
    
    while IFS='|' read -r new_filename original_filename status source_size dest_size source_hash dest_hash; do
        ((current_file++))
        
        log_message "Verifying file $current_file/$total_files: $new_filename"
        
        # Construct file paths
        local source_file="$source_path/$original_filename"
        local dest_file="$destination_path/$new_filename"
        
        # Check if source file exists
        if [ ! -f "$source_file" ]; then
            log_message "ERROR: Source file not found: $source_file"
            echo "$new_filename|$original_filename|failed|0|0||" >> "$temp_dest_offload"
            ((failed_count++))
            continue
        fi
        
        # Check if destination file exists
        if [ ! -f "$dest_file" ]; then
            log_message "ERROR: Destination file not found: $dest_file"
            echo "$new_filename|$original_filename|failed|0|0||" >> "$temp_dest_offload"
            ((failed_count++))
            continue
        fi
        
        # Calculate current hashes and sizes
        log_message "Calculating current file hashes..."
        local current_source_hash=$(calculate_hash "$source_file")
        local current_source_size=$(get_file_size "$source_file")
        local current_dest_hash=$(calculate_hash "$dest_file")
        local current_dest_size=$(get_file_size "$dest_file")
        
        # Verify sizes match
        if [ "$current_source_size" != "$current_dest_size" ]; then
            log_message "ERROR: Size mismatch for $new_filename (source: $current_source_size, dest: $current_dest_size)"
            echo "$new_filename|$original_filename|failed|$current_source_size|$current_dest_size|$current_source_hash|$current_dest_hash" >> "$temp_dest_offload"
            ((failed_count++))
            continue
        fi
        
        # Verify hashes match
        if [ "$current_source_hash" != "$current_dest_hash" ]; then
            log_message "ERROR: Hash mismatch for $new_filename"
            log_message "Source hash: $current_source_hash"
            log_message "Dest hash: $current_dest_hash"
            echo "$new_filename|$original_filename|failed|$current_source_size|$current_dest_size|$current_source_hash|$current_dest_hash" >> "$temp_dest_offload"
            ((failed_count++))
            continue
        fi
        
        echo "$new_filename|$original_filename|verified|$current_source_size|$current_dest_size|$current_source_hash|$current_dest_hash" >> "$temp_dest_offload"
        
        log_message "✓ Verified: $new_filename (size: $current_source_size, hash: ${current_source_hash:0:8}...)"
        ((verified_count++))
        
    done < "$dest_offload_file"
    
    # Replace destination .offload file with updated version
    mv "$temp_dest_offload" "$dest_offload_file"
    
    log_message "Verification complete!"
    log_message "Total files: $total_files"
    log_message "Verified: $verified_count"
    log_message "Failed: $failed_count"
    
    echo "Verification complete! $verified_count/$total_files files verified successfully."
}

# Main verify function
verify() {
    local source_path="$1"
    local destination_path="$2"
    
    log_message "Starting verification process"
    log_message "Source: $source_path"
    log_message "Destination: $destination_path"
    
    # Validate parameters
    validate_verify_params "$source_path" "$destination_path"
    
    # Check for source .offload file
    local source_offload_file="$source_path/.offload"
    if [ -f "$source_offload_file" ]; then
        log_message "Found source .offload file: $source_offload_file"
        
        # Determine destination path from source .offload if not provided
        if [ -z "$destination_path" ]; then
            # Read first line to get destination path
            local first_line=$(head -n 1 "$source_offload_file")
            if [ -n "$first_line" ]; then
                IFS='|' read -r source_file dest_file new_filename status <<< "$first_line"
                destination_path=$(dirname "$dest_file")
                log_message "Extracted destination path from .offload file: $destination_path"
            else
                handle_error "Cannot determine destination path from .offload file"
            fi
        fi
        
        verify_with_source_offload "$source_path" "$source_offload_file" "$destination_path"
        
    else
        log_message "No source .offload file found"
        
        # Check if destination path is provided
        if [ -z "$destination_path" ]; then
            handle_error "Destination path required when no source .offload file exists"
        fi
        
        # Check for destination .offload file
        local dest_offload_file="$destination_path/.offload"
        if [ -f "$dest_offload_file" ]; then
            log_message "Found destination .offload file: $dest_offload_file"
            verify_with_destination_offload "$source_path" "$destination_path" "$dest_offload_file"
        else
            handle_error "No .offload file found in source or destination"
        fi
    fi
} 