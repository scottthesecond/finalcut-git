#!/bin/bash

# Offload and Verify file utilities
# This file provides centralized functions for reading, writing, and updating
# .offload and .verify files in a robust and maintainable way.

# File format constants
OFFLOAD_FIELDS="source_file|dest_file|new_filename|status|source_size|dest_size|source_hash|dest_hash"
VERIFY_FIELDS="file_path|hash|size"

# Field indices for easy access
OFFLOAD_SOURCE_FILE=1
OFFLOAD_DEST_FILE=2
OFFLOAD_NEW_FILENAME=3
OFFLOAD_STATUS=4
OFFLOAD_SOURCE_SIZE=5
OFFLOAD_DEST_SIZE=6
OFFLOAD_SOURCE_HASH=7
OFFLOAD_DEST_HASH=8

VERIFY_FILE_PATH=1
VERIFY_HASH=2
VERIFY_SIZE=3

# Status constants
STATUS_QUEUED="queued"
STATUS_UNVERIFIED="unverified"
STATUS_VERIFIED="verified"
STATUS_FAILED="failed"

# Global variable to track temporary files
TEMP_FILES=""

# Function to create temporary file with unique name
create_temp_file() {
    local prefix="$1"
    local temp_file="/tmp/${prefix}_$$"
    # Track temporary files for cleanup
    if [ -n "$TEMP_FILES" ]; then
        TEMP_FILES="$TEMP_FILES $temp_file"
    else
        TEMP_FILES="$temp_file"
    fi
    echo "$temp_file"
}

# Function to cleanup temporary files
cleanup_temp_files() {
    if [ -n "$TEMP_FILES" ]; then
        for temp_file in $TEMP_FILES; do
            if [ -f "$temp_file" ]; then
                rm -f "$temp_file" 2>/dev/null || log_message "Warning: Failed to remove temp file: $temp_file"
            fi
        done
        TEMP_FILES=""
    fi
}

# Initialize cleanup trap
trap cleanup_temp_files EXIT

# Function to normalize file paths (remove double slashes and trailing slashes)
normalize_path() {
    local path="$1"
    echo "$path" | sed 's|//*|/|g' | sed 's|/$||'
}

# Function to calculate progress percentage with multi-step support
calculate_progress() {
    local current="$1"
    local total="$2"
    local base="$3"
    local range="$4"
    
    # If global progress tracker is not set, use single-step calculation
    if [ -z "$PROGRESS_TOTAL_STEPS" ] || [ -z "$PROGRESS_CURRENT_STEP" ]; then
        echo $((base + (current * range / total)))
        return
    fi
    
    # Multi-step progress calculation
    local step_progress=$((base + (current * range / total)))
    local step_weight=$((100 / PROGRESS_TOTAL_STEPS))
    local previous_steps_progress=$(((PROGRESS_CURRENT_STEP - 1) * step_weight))
    local current_step_progress=$((step_progress * step_weight / 100))
    
    echo $((previous_steps_progress + current_step_progress))
}

# Function to initialize progress tracker for multi-step operations
init_progress_tracker() {
    local total_steps="$1"
    local current_step="$2"
    local step_name="$3"
    
    export PROGRESS_TOTAL_STEPS="$total_steps"
    export PROGRESS_CURRENT_STEP="$current_step"
    export PROGRESS_STEP_NAME="$step_name"
    
    log_message "Progress tracker initialized: step $current_step of $total_steps - $step_name"
}

# Function to clear progress tracker
clear_progress_tracker() {
    unset PROGRESS_TOTAL_STEPS
    unset PROGRESS_CURRENT_STEP
    unset PROGRESS_STEP_NAME
    
    log_message "Progress tracker cleared"
}

# Function to validate file path exists and is readable
validate_file_path() {
    local file_path="$1"
    local description="$2"
    
    if [ -z "$file_path" ]; then
        log_message "ERROR: $description path is empty"
        return 1
    fi
    
    if [ ! -f "$file_path" ]; then
        log_message "ERROR: $description file does not exist: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        log_message "ERROR: $description file is not readable: $file_path"
        return 1
    fi
    
    return 0
}

# Function to validate directory path exists and is writable
validate_directory_path() {
    local dir_path="$1"
    local description="$2"
    local check_writable="$3"
    
    if [ -z "$dir_path" ]; then
        log_message "ERROR: $description path is empty"
        return 1
    fi
    
    if [ ! -d "$dir_path" ]; then
        log_message "ERROR: $description directory does not exist: $dir_path"
        return 1
    fi
    
    if [ "$check_writable" = "true" ] && [ ! -w "$dir_path" ]; then
        log_message "ERROR: $description directory is not writable: $dir_path"
        return 1
    fi
    
    return 0
}

# Function to validate offload parameters
validate_offload_params() {
    local input_path="$1"
    local output_path="$2"
    local project_shortname="$3"
    local source_name="$4"
    local type="$5"
    
    # Validate input path
    if ! validate_directory_path "$input_path" "Input" "false"; then
        return 1
    fi
    
    # Validate output path (don't check if writable yet, directory might not exist)
    if [ -z "$output_path" ]; then
        log_message "ERROR: Output path is required"
        return 1
    fi
    
    # Validate project shortname
    if [ -z "$project_shortname" ]; then
        log_message "ERROR: Project shortname is required"
        return 1
    fi
    
    # Validate source name
    if [ -z "$source_name" ]; then
        log_message "ERROR: Source name is required"
        return 1
    fi
    
    # Validate type
    if ! validate_offload_type "$type"; then
        log_message "ERROR: Invalid offload type: $type"
        return 1
    fi
    
    return 0
}

# Function to validate verify parameters
validate_verify_params() {
    local source_path="$1"
    local destination_path="$2"
    
    # Check if source path is provided
    if [ -z "$source_path" ]; then
        log_message "ERROR: Usage: verify <source_path> [destination_path]"
        return 1
    fi
    
    # Validate source path exists
    if ! validate_directory_path "$source_path" "Source" "false"; then
        return 1
    fi
    
    # Validate destination path if provided
    if [ -n "$destination_path" ]; then
        if ! validate_directory_path "$destination_path" "Destination" "false"; then
            return 1
        fi
    fi
    
    return 0
}

# Function to parse an offload file line into variables
# Usage: parse_offload_line "$line" && echo "Source: $source_file, Dest: $dest_file"
parse_offload_line() {
    local line="$1"
    
    # Check if line is empty
    if [ -z "$line" ]; then
        return 1
    fi
    
    # Parse the line into variables
    IFS='|' read -r source_file dest_file new_filename status source_size dest_size source_hash dest_hash <<< "$line"
    
    # Validate that we have the expected number of fields
    if [ -z "$source_file" ] || [ -z "$dest_file" ] || [ -z "$new_filename" ] || [ -z "$status" ]; then
        log_message "ERROR: Invalid offload line format: $line"
        return 1
    fi
    
    # Normalize paths
    source_file=$(normalize_path "$source_file")
    dest_file=$(normalize_path "$dest_file")
    
    return 0
}

# Function to parse a verify file line into variables
# Usage: parse_verify_line "$line" && echo "File: $file_path, Hash: $hash"
parse_verify_line() {
    local line="$1"
    
    # Check if line is empty
    if [ -z "$line" ]; then
        return 1
    fi
    
    # Parse the line into variables
    IFS='|' read -r file_path hash size <<< "$line"
    
    # Validate that we have the expected number of fields
    if [ -z "$file_path" ] || [ -z "$hash" ]; then
        log_message "ERROR: Invalid verify line format: $line"
        return 1
    fi
    
    # Normalize path
    file_path=$(normalize_path "$file_path")
    
    return 0
}

# Function to write an offload entry directly to file
# Usage: write_offload_entry "$file" "$source_file" "$dest_file" "$new_filename" "$status" "$source_size" "$dest_size" "$source_hash" "$dest_hash"
write_offload_entry() {
    local file="$1"
    local source_file="$2"
    local dest_file="$3"
    local new_filename="$4"
    local status="$5"
    local source_size="$6"
    local dest_size="$7"
    local source_hash="$8"
    local dest_hash="$9"
    
    # Normalize paths
    source_file=$(normalize_path "$source_file")
    dest_file=$(normalize_path "$dest_file")
    
    # Create the entry
    local entry="${source_file}|${dest_file}|${new_filename}|${status}|${source_size}|${dest_size}|${source_hash}|${dest_hash}"
    
    # Write to file
    echo "$entry" >> "$file"
    
    # Log for debugging
    log_message "Added offload entry: $new_filename (status: $status)"
}

# Function to write a verify entry directly to file
# Usage: write_verify_entry "$file" "$file_path" "$hash" "$size"
write_verify_entry() {
    local file="$1"
    local file_path="$2"
    local hash="$3"
    local size="$4"
    
    # Normalize path
    file_path=$(normalize_path "$file_path")
    
    # Create the entry
    local entry="${file_path}|${hash}|${size}"
    
    # Write to file
    echo "$entry" >> "$file"
    
    # Log for debugging
    log_message "Added verify entry: $(basename "$file_path") (hash: ${hash:0:8}...)"
}

# Function to read an offload file and process each entry with a callback
# Usage: read_offload_file "$file" "process_entry"
read_offload_file() {
    local file="$1"
    local callback="$2"
    
    if [ ! -f "$file" ]; then
        log_message "ERROR: Offload file does not exist: $file"
        return 1
    fi
    
    local line_number=0
    while IFS= read -r line; do
        ((line_number++))
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Parse the line
        if parse_offload_line "$line"; then
            # Call the callback function with parsed variables
            if [ -n "$callback" ]; then
                $callback "$line_number" "$source_file" "$dest_file" "$new_filename" "$status" "$source_size" "$dest_size" "$source_hash" "$dest_hash"
            fi
        else
            log_message "ERROR: Failed to parse line $line_number in $file"
        fi
    done < "$file"
}

# Function to read a verify file and process each entry with a callback
# Usage: read_verify_file "$file" "process_entry"
read_verify_file() {
    local file="$1"
    local callback="$2"
    
    if [ ! -f "$file" ]; then
        log_message "ERROR: Verify file does not exist: $file"
        return 1
    fi
    
    local line_number=0
    while IFS= read -r line; do
        ((line_number++))
        
        # Skip empty lines
        if [ -z "$line" ]; then
            continue
        fi
        
        # Parse the line
        if parse_verify_line "$line"; then
            # Call the callback function with parsed variables
            if [ -n "$callback" ]; then
                $callback "$line_number" "$file_path" "$hash" "$size"
            fi
        else
            log_message "ERROR: Failed to parse line $line_number in $file"
        fi
    done < "$file"
}

# Function to write an offload file atomically
# Usage: write_offload_file "$file" "entries_array"
write_offload_file() {
    local file="$1"
    local entries=("${@:2}")
    
    local temp_file=$(create_temp_file "offload_write")
    
    # Write all entries to temp file
    for entry in "${entries[@]}"; do
        echo "$entry" >> "$temp_file"
    done
    
    # Move temp file to final location
    if mv "$temp_file" "$file"; then
        log_message "Successfully wrote offload file: $file"
        return 0
    else
        log_message "ERROR: Failed to write offload file: $file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Function to write a verify file atomically
# Usage: write_verify_file "$file" "entries_array"
write_verify_file() {
    local file="$1"
    local entries=("${@:2}")
    
    local temp_file=$(create_temp_file "verify_write")
    
    # Write all entries to temp file
    for entry in "${entries[@]}"; do
        echo "$entry" >> "$temp_file"
    done
    
    # Move temp file to final location
    if mv "$temp_file" "$file"; then
        log_message "Successfully wrote verify file: $file"
        return 0
    else
        log_message "ERROR: Failed to write verify file: $file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Function to update offload status by line number
# Usage: update_offload_status_by_line "$file" "$line_number" "$old_status" "$new_status"
update_offload_status_by_line() {
    local file="$1"
    local line_number="$2"
    local old_status="$3"
    local new_status="$4"
    
    if [ ! -f "$file" ]; then
        log_message "ERROR: Offload file does not exist: $file"
        return 1
    fi
    
    local temp_file=$(create_temp_file "offload_update")
    
    # Use awk to update the specific line
    if awk -F'|' -v n="$line_number" -v old="$old_status" -v new="$new_status" '
        NR == n {
            if ($4 == old) {
                $4 = new
                updated = 1
            } else {
                warning = 1
            }
        }
        { print $0 }
        END {
            if (updated) {
                printf "Updated line %d status from %s to %s\n", n, old, new > "/dev/stderr"
            }
            if (warning) {
                printf "WARNING: Line %d status is %s, expected %s\n", n, $4, old > "/dev/stderr"
            }
        }
    ' OFS='|' "$file" > "$temp_file"; then
        
        # Move temp file to final location
        if mv "$temp_file" "$file"; then
            log_message "Successfully updated offload file: $file"
            return 0
        else
            log_message "ERROR: Failed to update offload file: $file"
            rm -f "$temp_file" 2>/dev/null
            return 1
        fi
    else
        log_message "ERROR: Failed to process offload file: $file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Function to update offload status by source file
# Usage: update_offload_status_by_source "$file" "$source_file" "$new_status"
update_offload_status_by_source() {
    local file="$1"
    local source_file="$2"
    local new_status="$3"
    
    if [ ! -f "$file" ]; then
        log_message "ERROR: Offload file does not exist: $file"
        return 1
    fi
    
    # Normalize the source file path
    source_file=$(normalize_path "$source_file")
    
    local temp_file=$(create_temp_file "offload_update")
    
    # Use awk to update the matching line
    if awk -F'|' -v key="$source_file" -v new="$new_status" '
        $1 == key {
            old_status = $4
            $4 = new
            updated = 1
        }
        { print $0 }
        END {
            if (updated) {
                printf "Updated status for %s from %s to %s\n", key, old_status, new > "/dev/stderr"
            }
        }
    ' OFS='|' "$file" > "$temp_file"; then
        
        # Move temp file to final location
        if mv "$temp_file" "$file"; then
            log_message "Successfully updated offload file: $file"
            return 0
        else
            log_message "ERROR: Failed to update offload file: $file"
            rm -f "$temp_file" 2>/dev/null
            return 1
        fi
    else
        log_message "ERROR: Failed to process offload file: $file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Function to update all failed statuses to queued (for retry)
# Usage: update_failed_to_queued "$file"
update_failed_to_queued() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        log_message "ERROR: Offload file does not exist: $file"
        return 1
    fi
    
    local temp_file=$(create_temp_file "offload_retry")
    
    # Use awk to update all failed statuses
    if awk -F'|' -v new="$STATUS_QUEUED" '
        $4 == "failed" {
            $4 = new
            count++
        }
        { print $0 }
        END {
            if (count > 0) {
                printf "Updated %d failed entries to queued\n", count > "/dev/stderr"
            }
        }
    ' OFS='|' "$file" > "$temp_file"; then
        
        # Move temp file to final location
        if mv "$temp_file" "$file"; then
            log_message "Successfully updated offload file for retry: $file"
            return 0
        else
            log_message "ERROR: Failed to update offload file: $file"
            rm -f "$temp_file" 2>/dev/null
            return 1
        fi
    else
        log_message "ERROR: Failed to process offload file: $file"
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

# Function to get offload statistics
# Usage: get_offload_stats "$file"
get_offload_stats() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo "0|0|0|0|0"
        return 0
    fi
    
    local total_files=0
    local completed_files=0
    local failed_files=0
    local queued_files=0
    local unverified_files=0
    
    # Process each line
    while IFS= read -r line; do
        if [ -z "$line" ]; then
            continue
        fi
        
        if parse_offload_line "$line"; then
            ((total_files++))
            case "$status" in
                "$STATUS_VERIFIED")
                    ((completed_files++))
                    ;;
                "$STATUS_FAILED")
                    ((failed_files++))
                    ;;
                "$STATUS_QUEUED")
                    ((queued_files++))
                    ;;
                "$STATUS_UNVERIFIED")
                    ((unverified_files++))
                    ;;
            esac
        fi
    done < "$file"
    
    echo "$total_files|$completed_files|$failed_files|$queued_files|$unverified_files"
}

# Function to check if a file exists in a verify file
file_exists_in_verify() {
    local input_file_path="$1"
    local verify_file="$2"
    
    if [ ! -f "$verify_file" ]; then
        return 1
    fi
    
    # Normalize the file path
    input_file_path=$(normalize_path "$input_file_path")
    
    # Check if the file exists in the verify file
    while IFS= read -r line; do
        local file_path hash size
        if IFS='|' read -r file_path hash size <<< "$line"; then
            file_path=$(normalize_path "$file_path")
            if [ "$input_file_path" = "$file_path" ]; then
                return 0
            fi
        fi
    done < "$verify_file"
    
    return 1
}

# Function to check if source file exists and is readable
check_source_file_exists() {
    local source_file="$1"
    local description="$2"
    
    if [ ! -f "$source_file" ]; then
        log_message "ERROR: Source file not found: $source_file"
        if [ -n "$description" ]; then
            show_details "✗ Source file not found: $description"
        fi
        return 1
    fi
    
    if [ ! -r "$source_file" ]; then
        log_message "ERROR: Source file not readable: $source_file"
        if [ -n "$description" ]; then
            show_details "✗ Source file not readable: $description"
        fi
        return 1
    fi
    
    return 0
}

# Function to check if destination file exists and is readable
check_dest_file_exists() {
    local dest_file="$1"
    local description="$2"
    
    if [ ! -f "$dest_file" ]; then
        log_message "ERROR: Destination file not found: $dest_file"
        if [ -n "$description" ]; then
            show_details "✗ Destination file not found: $description"
        fi
        return 1
    fi
    
    if [ ! -r "$dest_file" ]; then
        log_message "ERROR: Destination file not readable: $dest_file"
        if [ -n "$description" ]; then
            show_details "✗ Destination file not readable: $description"
        fi
        return 1
    fi
    
    return 0
}

# Function to check if destination directory exists and is writable
check_dest_directory_writable() {
    local dest_dir="$1"
    local description="$2"
    
    if [ ! -d "$dest_dir" ]; then
        log_message "ERROR: Destination directory does not exist: $dest_dir"
        if [ -n "$description" ]; then
            show_details "✗ Destination directory does not exist: $description"
        fi
        return 1
    fi
    
    if [ ! -w "$dest_dir" ]; then
        log_message "ERROR: Destination directory is not writable: $dest_dir"
        if [ -n "$description" ]; then
            show_details "✗ Destination directory is not writable: $description"
        fi
        return 1
    fi
    
    return 0
}

# Function to extract destination path from offload file
extract_destination_path_from_offload() {
    local offload_file="$1"
    local provided_output_path="$2"
    
    # If output path is provided, use it
    if [ -n "$provided_output_path" ]; then
        echo "$provided_output_path"
        return 0
    fi
    
    # Extract destination path from first line of offload file
    local first_line=$(head -n 1 "$offload_file")
    if [ -n "$first_line" ]; then
        if parse_offload_line "$first_line"; then
            local extracted_path=$(dirname "$dest_file")
            log_message "Extracted destination path from .offload file: $extracted_path"
            echo "$extracted_path"
            return 0
        else
            log_message "ERROR: Cannot parse destination path from .offload file"
            return 1
        fi
    else
        log_message "ERROR: Cannot determine destination path from .offload file"
        return 1
    fi
}

# Function to extract source name from existing offload file
extract_source_name_from_offload() {
    local offload_file="$1"
    
    # Extract source name from first line of offload file
    local first_line=$(head -n 1 "$offload_file")
    if [ -n "$first_line" ]; then
        if parse_offload_line "$first_line"; then
            # Extract source name from new_filename field
            # Format: v0001.PROJ.source_name.0001.ext or v0001.PROJ.source_name.0001(original).ext
            local source_name=""
            if [[ "$new_filename" =~ \.([^.]+)\.[0-9]{4}\. ]]; then
                source_name="${BASH_REMATCH[1]}"
                log_message "Extracted source name from .offload file: $source_name"
                echo "$source_name"
                return 0
            else
                log_message "ERROR: Cannot parse source name from new_filename: $new_filename"
                return 1
            fi
        else
            log_message "ERROR: Cannot parse .offload file line"
            return 1
        fi
    else
        log_message "ERROR: .offload file is empty"
        return 1
    fi
}

# Function to calculate SHA256 hash of a file
calculate_hash() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        log_message "ERROR: File does not exist for hash calculation: $file_path"
        return 1
    fi
    
    if [ ! -r "$file_path" ]; then
        log_message "ERROR: File is not readable for hash calculation: $file_path"
        return 1
    fi
    
    # Calculate SHA256 hash
    local hash=$(shasum -a 256 "$file_path" 2>/dev/null | cut -d' ' -f1)
    
    if [ -z "$hash" ]; then
        log_message "ERROR: Failed to calculate hash for: $file_path"
        return 1
    fi
    
    echo "$hash"
}

# Function to calculate file hash with error handling and user feedback
calculate_file_hash() {
    local file_path="$1"
    local description="$2"
    
    local hash=$(calculate_hash "$file_path")
    if [ -z "$hash" ]; then
        if [ -n "$description" ]; then
            show_details "✗ Hash calculation failed: $description"
        fi
        return 1
    fi
    
    echo "$hash"
}

# Function to get file size safely with error handling
get_file_size_safe() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        log_message "ERROR: File does not exist for size calculation: $file_path"
        echo "0"
        return 1
    fi
    
    local size=$(stat -f%z "$file_path" 2>/dev/null || echo "0")
    echo "$size"
}

# Function to get file size (legacy function for compatibility)
get_file_size() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to compare file sizes and log errors
compare_file_sizes() {
    local source_size="$1"
    local dest_size="$2"
    local source_file="$3"
    local dest_file="$4"
    
    if [ "$source_size" != "$dest_size" ]; then
        log_message "ERROR: Size mismatch for $(basename "$source_file") (source: $source_size, dest: $dest_size)"
        show_details "✗ Size mismatch for $(basename "$source_file")"
        return 1
    fi
    
    return 0
}

# Function to compare file hashes and log errors
compare_file_hashes() {
    local source_hash="$1"
    local dest_hash="$2"
    local source_file="$3"
    local dest_file="$4"
    
    if [ "$source_hash" != "$dest_hash" ]; then
        log_message "ERROR: Hash mismatch for $(basename "$source_file")"
        log_message "Source hash: $source_hash"
        log_message "Dest hash: $dest_hash"
        show_details "✗ Hash mismatch for $(basename "$source_file")"
        return 1
    fi
    
    return 0
}