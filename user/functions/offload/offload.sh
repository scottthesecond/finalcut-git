#!/bin/bash

# Offload script for SD card footage
# Usage: offload <input_path> <output_path> <project_shortname> <source_name> <type>

# Function to check if a file or folder is AVCHD (case-insensitive)
is_avchd() {
    local path="$1"
    # Use tr to lowercase and grep for 'avchd'
    if echo "$path" | tr '[:upper:]' '[:lower:]' | grep -q 'avchd'; then
        return 0
    else
        return 1
    fi
}

# Function to check if file should be skipped and return reason
should_skip_file() {
    local file_path="$1"
    local type="$2"
    local reason=""
    local extension=$(echo "${file_path##*.}" | tr '[:upper:]' '[:lower:]')
    local filename=$(basename "$file_path")
    
    # Skip system files for all types
    case "$filename" in
        .fseventsd|fseventsd-uuid|.ignore|.offload|.hedge-enabled)
            reason="Skip system file: $filename"
            echo "$reason"
            return 0
            ;;
    esac
    
    # Skip files within hidden folders
    local dir_path=$(dirname "$file_path")
    if [[ "$dir_path" == *"/."* ]]; then
        reason="Skip file in hidden folder: $(basename "$dir_path")"
        echo "$reason"
        return 0
    fi
    
    # AVCHD skip if <2MB
    if is_avchd "$file_path"; then
        local file_size=$(stat -f%z "$file_path" 2>/dev/null || echo "0")
        if [ "$file_size" -lt 2097152 ]; then
            reason="AVCHD file/folder <2MB"
            echo "$reason"
            return 0
        fi
    fi
    
    # Audio type skips
    if [[ "$type" =~ ^(audio|a)$ ]]; then
        case "$extension" in
            sys|zst|dat|db|url|bk|scr|thm|gis|log)
                reason="Audio skip: $extension file"
                echo "$reason"
                return 0
                ;;
        esac
    fi
    # Video type skips
    if [[ "$type" =~ ^(video|v)$ ]]; then
        case "$extension" in
            thumbs|xml|ctg|dat|cpc|cpg|b00|d00|scr|thm|log|jpg|tbl)
                reason="Video skip: $extension file"
                echo "$reason"
                return 0
                ;;
        esac
    fi
    
    return 1  # do not skip
}

# Function to generate filename with original name in parentheses for all file types (except maintain mode)
generate_filename_with_original() {
    local file_path="$1"
    local type_prefix="$2"
    local counter="$3"
    local project_shortname="$4"
    local source_name="$5"
    local file_counter="$6"
    local type="$7"
    
    local extension="${file_path##*.}"
    local original_filename=$(basename "$file_path" ".$extension")
    
    # For maintain mode, use original naming scheme without parentheses
    if [[ "$type" =~ ^(maintain|m)$ ]]; then
        echo "${type_prefix}$(printf "%04d" $counter).${project_shortname}.${source_name}.$(printf "%04d" $file_counter).${extension}"
    else
        # For all other types, include original filename in parentheses
        # Sanitize original filename for use in parentheses (remove special chars, limit length)
        local sanitized_original=$(echo "$original_filename" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g' | cut -c1-20)
        if [ -n "$sanitized_original" ]; then
            echo "${type_prefix}$(printf "%04d" $counter).${project_shortname}.${source_name}.$(printf "%04d" $file_counter)(${sanitized_original}).${extension}"
        else
            echo "${type_prefix}$(printf "%04d" $counter).${project_shortname}.${source_name}.$(printf "%04d" $file_counter).${extension}"
        fi
    fi
}

# Function to scan input directory and build file list
scan_input_directory() {
    local input_path="$1"
    local project_shortname="$2"
    local source_name="$3"
    local type="$4"
    local offload_file="$5"
    local counter="$6"
    local output_path="$7"  # Add output_path parameter
    
    local type_prefix=$(get_type_prefix "$type")
    local file_counter=1
    local skipped_count=0
    local ignore_file_src="$input_path/.ignore"
    local ignore_file_dest="$output_path/.ignore"  # Define ignore_file_dest here
    > "$ignore_file_src"
    # Don't create destination .ignore file yet - destination directory doesn't exist
    
    log_message "Scanning input directory: $input_path"
    show_details "Scanning input directory for files..."
    show_progress 10
    
    # Count total files first for progress calculation (before filtering)
    local total_files=$(find "$input_path" -type f | wc -l | tr -d ' ')
    log_message "Found $total_files total files to scan"
    show_details "Found $total_files total files to scan"
    
    # Find all files recursively and process them
    while IFS= read -r file_path; do
        # Skip the .offload file itself and any backup files
        if [[ "$file_path" == *".offload"* ]]; then
            continue
        fi
        
        # Check if file should be skipped and get reason
        local skip_reason=""
        skip_reason=$(should_skip_file "$file_path" "$type")
        if [ $? -eq 0 ]; then
            ((skipped_count++))
            log_message "Skipping $file_path: $skip_reason"
            echo "$file_path|$skip_reason" >> "$ignore_file_src"
            # Only write to destination .ignore if destination directory exists
            if [ -d "$(dirname "$ignore_file_dest")" ]; then
                echo "$file_path|$skip_reason" >> "$ignore_file_dest"
            fi
            continue
        fi
        
        # Get file extension
        local extension="${file_path##*.}"
        
        # Generate new filename with counter
        local new_filename=$(generate_filename_with_original "$file_path" "$type_prefix" "$counter" "$project_shortname" "$source_name" "$file_counter" "$type")
        
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
            # Normalize path to avoid double slashes
            dest_path=$(echo "$output_path/$new_filename" | sed 's|//*|/|g')
        fi
        
        # Add to offload file using the utility function
        write_offload_entry "$offload_file" "$file_path" "$dest_path" "$new_filename" "$STATUS_QUEUED" "0" "0" "" ""
        
        log_message "Queued: $file_path -> $dest_path"
        ((file_counter++))
    done < <(find "$input_path" -type f)
    
    log_message "Scan complete. Found $((file_counter-1)) files to offload, skipped $skipped_count files"
    show_details "Scan complete. Found $((file_counter-1)) files to offload, skipped $skipped_count files"
    show_progress 20
}

# Function to copy files and update status
copy_files() {
    local offload_file="$1"
    local output_path="$2"
    local input_path="$3"
    local total_files=$(wc -l < "$offload_file")
    local current_file=0
    
    # Create destination directory
    mkdir -p "$output_path"
    
    # Create destination offload file (same format as source)
    # Normalize path to avoid double slashes
    local dest_offload_file=$(echo "$output_path/.offload" | sed 's|//*|/|g')
    > "$dest_offload_file"
    
    # Create destination ignore file by copying from source if it exists
    local ignore_file_src="$input_path/.ignore"
    local ignore_file_dest=$(echo "$output_path/.ignore" | sed 's|//*|/|g')
    if [ -f "$ignore_file_src" ]; then
        cp "$ignore_file_src" "$ignore_file_dest"
        log_message "Created destination ignore file: $ignore_file_dest"
    fi
    
    log_message "Starting file copy process for $total_files files"
    show_details "Starting file copy process..."
    show_details "Copying $total_files files..."
    
    while IFS='|' read -r source_path dest_path new_filename status source_size dest_size source_hash dest_hash; do
        ((current_file++))
        
        if [ "$status" = "queued" ] || [ "$status" = "unverified" ]; then
            # Calculate progress percentage (20-80% range for copy phase)
            local progress=$(calculate_progress $current_file $total_files 20 60)
            show_progress $progress
            
            log_message "Copying file $current_file/$total_files: $source_path"
            show_details "Transferring file $current_file/$total_files"
            
            # Copy the file and capture any error output
            local copy_output
            if copy_output=$(cp "$source_path" "$dest_path" 2>&1); then
                # Verify the copy was successful by checking file existence and size
                if ! check_dest_file_exists "$dest_path" "$new_filename"; then
                    log_message "ERROR: Copy appeared successful but destination file doesn't exist: $dest_path"
                    update_offload_status_by_line "$offload_file" "$current_file" "$status" "$STATUS_FAILED"
                    continue
                fi
                
                # Get source and destination sizes for comparison
                local source_size_actual=$(get_file_size_safe "$source_path")
                local dest_size_actual=$(get_file_size_safe "$dest_path")
                
                if ! compare_file_sizes "$source_size_actual" "$dest_size_actual" "$source_path" "$dest_path"; then
                    # Remove the incomplete destination file
                    rm -f "$dest_path" 2>/dev/null
                    update_offload_status_by_line "$offload_file" "$current_file" "$status" "$STATUS_FAILED"
                    continue
                fi
                
                # Update status to unverified
                update_offload_status_by_line "$offload_file" "$current_file" "$status" "$STATUS_UNVERIFIED"
                
                # Add same entry to destination offload file with actual sizes
                write_offload_entry "$dest_offload_file" "$source_path" "$dest_path" "$new_filename" "$STATUS_UNVERIFIED" "$source_size_actual" "$dest_size_actual" "$source_hash" "$dest_hash"
                
                log_message "Successfully copied: $new_filename (size: $source_size_actual bytes)"
                show_details "✓ Copied: $new_filename"
            else
                log_message "ERROR: Failed to copy $source_path: $copy_output"
                show_details "✗ Failed to copy: $(basename "$source_path")"
                # Remove any partial destination file that might have been created
                rm -f "$dest_path" 2>/dev/null
                # Update status to failed
                update_offload_status_by_line "$offload_file" "$current_file" "$status" "$STATUS_FAILED"
            fi
        fi
    done < "$offload_file"
    
    log_message "File copy process complete"
    show_details "File copy process complete"
    show_progress 80
    log_message "Created destination mapping file: $dest_offload_file"
}

# Function to check offload status from .offload file
check_offload_status() {
    local offload_file="$1"
    
    if [ ! -f "$offload_file" ]; then
        echo "none"
        return
    fi

    # Get statistics using the utility function
    local stats=$(get_offload_stats "$offload_file")
    IFS='|' read -r total_files completed_files failed_files queued_files unverified_files <<< "$stats"

    log_message "DEBUG: check_offload_status: total_files=$total_files, completed_files=$completed_files, failed_files=$failed_files, queued_files=$queued_files, unverified_files=$unverified_files"

    # Determine overall status
    if [ "$total_files" -eq 0 ]; then
        echo "none"
    elif [ "$queued_files" -gt 0 ]; then
        echo "incomplete"
    elif [ "$failed_files" -gt 0 ] && [ "$queued_files" -eq 0 ]; then
        echo "failed"
    elif [ "$completed_files" -eq "$total_files" ]; then
        echo "complete"
    else
        echo "unknown"
    fi
}

# Function to get offload statistics (wrapper for utility function)
get_offload_stats_wrapper() {
    local offload_file="$1"
    
    if [ ! -f "$offload_file" ]; then
        echo "0|0|0|0|0"
        return
    fi

    # Use the utility function from offload_file_utils.sh
    get_offload_stats "$offload_file"
}

# Function to prompt user for source name
prompt_source_name() {
    local input_path="$1"
    local default_name=""
    
    # Try to generate a default name from the input path
    if [ -n "$input_path" ]; then
        default_name=$(basename "$input_path" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]//g')
        if [ -z "$default_name" ]; then
            default_name="source"
        fi
    fi
    
    # Prompt for source name using AppleScript with proper button handling
    local result=$(osascript -e "display dialog \"Enter a name for this card:\" default answer \"$default_name\" buttons {\"Cancel\", \"OK\"} default button \"OK\"" 2>&1)
    local osascript_status=$?
    
    # Check if osascript failed
    if [ $osascript_status -ne 0 ]; then
        log_message "Error: Failed to display source name dialog. Status: $osascript_status, Error: $result"
        return 1
    fi
    
    # Parse the result
    local button_clicked=$(echo "$result" | sed -n 's/.*button returned:\(.*\), text returned.*/\1/p' | tr -d ', ')
    local source_name=$(echo "$result" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')
    
    if [ "$button_clicked" = "Cancel" ]; then
        log_message "User canceled source name dialog"
        return 1
    fi
    
    if [ -n "$source_name" ]; then
        log_message "Source name entered: $source_name"
        echo "$source_name"
        return 0
    else
        log_message "No source name entered"
        return 1
    fi
}

# Function to prompt user for offload action when existing file is found
prompt_offload_action() {
    local input_path="$1"
    local offload_file="$2"
    local status="$3"
    local stats="$4"
    
    IFS='|' read -r total_files completed_files failed_files queued_files unverified_files <<< "$stats"
    
    log_message "DEBUG: prompt_offload_action: total_files=$total_files, completed_files=$completed_files, failed_files=$failed_files, queued_files=$queued_files, unverified_files=$unverified_files, status=$status"

    local message=""
    local buttons=""
    
    case "$status" in
        "incomplete")
            message="An incomplete offload was found on this SD card.\n\nTotal files: $total_files\nCompleted: $completed_files\nFailed: $failed_files\nRemaining: $queued_files\n\nWould you like to resume the offload from where it left off?"
            buttons="Resume Offload|Start New Offload|Cancel"
            ;;
        "failed")
            message="A failed offload was found on this SD card.\n\nTotal files: $total_files\nCompleted: $completed_files\nFailed: $failed_files\n\nWould you like to retry the failed files or start a new offload?"
            buttons="Retry Failed Files|Start New Offload|Cancel"
            ;;
        "complete")
            message="A completed offload was found on this SD card.\n\nTotal files: $total_files\nAll files completed successfully.\n\nWould you like to re-verify the offload or start a new one?"
            buttons="Re-verify Offload|Start New Offload|Cancel"
            ;;
        *)
            message="An offload file was found on this SD card, but its status is unclear.\n\nWould you like to start a new offload?"
            buttons="Start New Offload|Cancel"
            ;;
    esac
    
    # Convert pipe-separated button names to properly quoted AppleScript format
    local quoted_buttons=""
    IFS='|' read -ra button_array <<< "$buttons"
    for button in "${button_array[@]}"; do
        if [ -n "$quoted_buttons" ]; then
            quoted_buttons="$quoted_buttons, \"$button\""
        else
            quoted_buttons="\"$button\""
        fi
    done
    
    # Run osascript and capture both output and error
    local result=$(osascript <<EOF
display dialog "$message" buttons {$quoted_buttons} default button 1 with title "Offload Status Detected"
button returned of result
EOF
 2>&1)
    local osascript_status=$?
    log_message "DEBUG: osascript raw result: $result, exit status: $osascript_status"
    
    # Check if osascript failed (user canceled or other error)
    if [ $osascript_status -ne 0 ]; then
        log_message "Error: Failed to display offload action dialog. Status: $osascript_status, Error: $result"
        echo "Cancel"
        return
    fi
    
    # Parse the result to get just the button name
    # osascript returns just the button name, not "button returned:ButtonName"
    local choice=$(echo "$result")
    log_message "DEBUG: parsed dialog choice: '$choice'"
    
    echo "$choice"
}

# Function to resume incomplete offload
resume_offload() {
    local input_path="$1"
    local output_path="$2"
    local project_shortname="$3"
    local source_name="$4"
    local type="$5"
    local counter="$6"
    local offload_file="$7"
    
    log_message "Resuming incomplete offload from: $offload_file"
    show_details "Resuming incomplete offload..."
    show_progress 5
    
    # Determine the correct destination path from the offload file
    local actual_output_path=""
    if ! actual_output_path=$(extract_destination_path_from_offload "$offload_file" "$output_path"); then
        handle_error "Cannot determine destination path from .offload file"
    fi
    
    show_details "Using existing destination: $(basename "$actual_output_path")"
    
    # Validate that the destination path exists and is writable
    if [ ! -d "$actual_output_path" ]; then
        handle_error "Destination path does not exist: $actual_output_path"
    fi
    
    if [ ! -w "$actual_output_path" ]; then
        handle_error "Destination path is not writable: $actual_output_path"
    fi
    
    # Get statistics
    local stats=$(get_offload_stats_wrapper "$offload_file")
    IFS='|' read -r total_files completed_files failed_files queued_files unverified_files <<< "$stats"
    
    log_message "Resume stats - Total: $total_files, Completed: $completed_files, Failed: $failed_files, Queued: $queued_files, Unverified: $unverified_files"
    show_details "Resuming: $queued_files files remaining"
    
    # Copy remaining files
    copy_files "$offload_file" "$actual_output_path" "$input_path"
    
    # Display summary
    local final_stats=$(get_offload_stats_wrapper "$offload_file")
    IFS='|' read -r final_total final_completed final_failed final_queued final_unverified <<< "$final_stats"
    
    show_progress 100
    show_details "Resume complete!"
    show_details "Total files: $final_total"
    show_details "Successfully copied: $final_completed"
    if [ "$final_failed" -gt 0 ]; then
        show_details "Failed: $final_failed"
    fi
    
    log_message "Resume complete!"
    log_message "Total files: $final_total"
    log_message "Successfully copied: $final_completed"
    if [ "$final_failed" -gt 0 ]; then
        log_message "Failed: $final_failed"
    fi
    
    echo "Resume complete! $final_completed files copied to $actual_output_path"
}

# Function to retry failed offload
retry_failed_offload() {
    local input_path="$1"
    local output_path="$2"
    local project_shortname="$3"
    local source_name="$4"
    local type="$5"
    local counter="$6"
    local offload_file="$7"

    log_message "Retrying failed offload from: $offload_file"
    show_details "Retrying failed offload..."
    show_progress 5

    # Determine the correct destination path from the offload file
    local actual_output_path=""
    if ! actual_output_path=$(extract_destination_path_from_offload "$offload_file" "$output_path"); then
        handle_error "Cannot determine destination path from .offload file"
    fi
    
    show_details "Using existing destination: $(basename "$actual_output_path")"
    
    # Validate that the destination path exists and is writable
    if [ ! -d "$actual_output_path" ]; then
        handle_error "Destination path does not exist: $actual_output_path"
    fi
    
    if [ ! -w "$actual_output_path" ]; then
        handle_error "Destination path is not writable: $actual_output_path"
    fi

    # Get statistics BEFORE modifying the file
    local stats=$(get_offload_stats_wrapper "$offload_file")
    IFS='|' read -r total_files completed_files failed_files queued_files unverified_files <<< "$stats"
    log_message "Retry stats - Total: $total_files, Completed: $completed_files, Failed: $failed_files, Unverified: $unverified_files"
    show_details "Retrying: $failed_files failed files"

    # Use the utility function to update all failed statuses to queued
    if ! update_failed_to_queued "$offload_file"; then
        handle_error "Failed to update offload file for retry"
    fi

    # Copy files (this will retry the failed ones)
    copy_files "$offload_file" "$actual_output_path" "$input_path"

    # Display summary
    local final_stats=$(get_offload_stats_wrapper "$offload_file")
    IFS='|' read -r final_total final_completed final_failed final_queued final_unverified <<< "$final_stats"

    show_progress 100
    show_details "Retry complete!"
    show_details "Total files: $final_total"
    show_details "Successfully copied: $final_completed"
    if [ "$final_failed" -gt 0 ]; then
        show_details "Failed: $final_failed"
    fi

    log_message "Retry complete!"
    log_message "Total files: $final_total"
    log_message "Successfully copied: $final_completed"
    if [ "$final_failed" -gt 0 ]; then
        log_message "Failed: $final_failed"
    fi

    echo "Retry complete! $final_completed files copied to $actual_output_path"
}

# Function to re-verify completed offload
reverify_offload() {
    local input_path="$1"
    local output_path="$2"
    local offload_file="$input_path/.offload"
    
    log_message "Re-verifying completed offload"
    show_details "Re-verifying completed offload..."
    
    # Determine the correct destination path from the offload file
    local actual_output_path=""
    if ! actual_output_path=$(extract_destination_path_from_offload "$offload_file" "$output_path"); then
        handle_error "Cannot determine destination path from .offload file"
    fi
    
    show_details "Using existing destination: $(basename "$actual_output_path")"
    
    # Validate that the destination path exists and is readable
    if [ ! -d "$actual_output_path" ]; then
        handle_error "Destination path does not exist: $actual_output_path"
    fi
    
    if [ ! -r "$actual_output_path" ]; then
        handle_error "Destination path is not readable: $actual_output_path"
    fi
    
    # Run verification
    verify "$input_path" "$actual_output_path" || handle_error "Re-verification failed"
    
    log_message "Re-verification complete"
    echo "Re-verification complete!"
}

# Main offload function
offload() {
    local input_path="$1"
    local output_path="$2"
    local project_shortname="$3"
    local source_name="$4"
    local type="$5"
    local counter="$6"
    
    log_message "Starting offload process"
    log_message "Input: $input_path"
    log_message "Output: $output_path"
    log_message "Project: $project_shortname"
    log_message "Source: $source_name"
    log_message "Type: $type"
    log_message "Counter: $counter"
    
    # Debug logging to check progressbar variable
    if [ "$DEBUG_MODE" = true ]; then
        echo "DEBUG: offload function - progressbar='$progressbar', DEBUG_MODE='$DEBUG_MODE'" >&2
    fi
    
    show_progress 5
    # show_details_on
    show_details "Starting offload process..."
    show_details "Input: $(basename "$input_path")"
    show_details "Output: $(basename "$output_path")"
    show_details "Project: $project_shortname"
    show_details "Type: $type"
    show_details "Counter: $counter"
    
    # Check for existing offload file first
    local offload_file="$input_path/.offload"
    local existing_offload=false
    
    if [ -f "$offload_file" ]; then
        existing_offload=true
        log_message "Found existing .offload file: $offload_file"
        show_details "Found existing offload file"
        
        # If no source name provided, try to extract from existing .offload file
        if [ -z "$source_name" ]; then
            if source_name=$(extract_source_name_from_offload "$offload_file"); then
                log_message "Extracted source name from existing .offload file: $source_name"
                show_details "Using existing source name: $source_name"
            else
                log_message "Failed to extract source name from .offload file, will prompt user"
            fi
        fi
        
        # Check offload status
        local status=$(check_offload_status "$offload_file")
        # Get stats BEFORE any file is cleared or overwritten
        local stats=$(get_offload_stats_wrapper "$offload_file")

        log_message "Offload status: $status"
        log_message "Offload stats: $stats"
        
        # If status is not "none", prompt user for action
        if [ "$status" != "none" ]; then
            show_details "Checking offload status..."
            
            # Prompt user for action
            local action=$(prompt_offload_action "$input_path" "$offload_file" "$status" "$stats")
            
            case "$action" in
                "Resume Offload")
                    log_message "User chose to resume offload"
                    show_details "Resuming offload..."
                    resume_offload "$input_path" "$output_path" "$project_shortname" "$source_name" "$type" "$counter" "$offload_file"
                    return 0
                    ;;
                "Retry Failed Files")
                    log_message "User chose to retry failed files"
                    show_details "Retrying failed files..."
                    retry_failed_offload "$input_path" "$output_path" "$project_shortname" "$source_name" "$type" "$counter" "$offload_file"
                    return 0
                    ;;
                "Re-verify Offload")
                    log_message "User chose to re-verify offload"
                    show_details "Re-verifying offload..."
                    reverify_offload "$input_path" "$output_path"
                    return 0
                    ;;
                "Start New Offload")
                    log_message "User chose to start new offload"
                    show_details "Starting new offload..."
                    # Continue with new offload process
                    ;;
                "Cancel")
                    log_message "User cancelled offload"
                    show_details "Offload cancelled by user"
                    echo "Offload cancelled"
                    return 0
                    ;;
                *)
                    log_message "Unknown action: $action"
                    show_details "Unknown action, aborting offload."
                    echo "Offload cancelled"
                    return 0
                    ;;
            esac
        fi
        
        # If we get here, either status was "none" or user chose "Start New Offload"
        # Only create backup if we're actually doing a resume/retry operation
        # For new offloads, we don't need a backup
        if [ "$status" != "none" ]; then
            log_message "Backing up existing .offload file to .offload.backup"
            show_details "Backing up existing offload file..."
            cp "$offload_file" "$offload_file.backup"
        fi
    fi
    
    # If no source name is available (either not provided or couldn't extract from .offload file), prompt user
    if [ -z "$source_name" ]; then
        show_details "Prompting for source name..."
        if ! source_name=$(prompt_source_name "$input_path"); then
            log_message "User cancelled source name prompt"
            show_details "Offload cancelled by user"
            echo "Offload cancelled"
            return 0
        fi
        log_message "Source name determined: $source_name"
        show_details "Source name: $source_name"
    fi
    
    # Validate parameters
    validate_offload_params "$input_path" "$output_path" "$project_shortname" "$source_name" "$type"
    
    # Create the full destination path if only base destination was provided
    local full_dest_path="$output_path"
    if [ -d "$output_path" ] && [ "$output_path" = "$(get_offload_config "DESTINATION")" ]; then
        # This is a base destination, create the full path with naming scheme
        local type_prefix=$(get_type_prefix "$type")
        local dest_folder="${type_prefix}$(printf "%04d" $counter).${project_shortname}.${source_name}"
        # Ensure output_path doesn't end with a slash to avoid double slashes
        local clean_output_path=$(echo "$output_path" | sed 's|/$||')
        # Normalize path to avoid double slashes
        full_dest_path=$(echo "$clean_output_path/$dest_folder" | sed 's|//*|/|g')
        log_message "Created full destination path: $full_dest_path"
        show_details "Destination: $(basename "$full_dest_path")"
    fi
    
    # Clear/create offload file
    > "$offload_file"
    log_message "Created offload tracking file: $offload_file"
    show_details "Created offload tracking file"
    
    # Scan input directory and build file list
    scan_input_directory "$input_path" "$project_shortname" "$source_name" "$type" "$offload_file" "$counter" "$full_dest_path"
    
    # Copy files and update status
    copy_files "$offload_file" "$full_dest_path" "$input_path"
    
    # Display summary - count successfully copied files (unverified status means copied but not yet verified)
    local total_files=$(wc -l < "$offload_file")
    local copied_count=$(grep -c "unverified" "$offload_file" 2>/dev/null || echo "0")
    local failed_count=$(grep -c "failed" "$offload_file" 2>/dev/null || echo "0")
    
    show_progress 100
    show_details "Offload complete!"
    show_details "Total files: $total_files"
    show_details "Successfully copied: $copied_count"
    if [ "$failed_count" -gt 0 ] 2>/dev/null; then
        show_details "Failed: $failed_count"
    fi
    
    log_message "Offload complete!"
    log_message "Total files: $total_files"
    log_message "Successfully copied: $copied_count"
    if [ "$failed_count" -gt 0 ] 2>/dev/null; then
        log_message "Failed: $failed_count"
    fi
    
    echo "Offload complete! $copied_count files copied to $full_dest_path"
} 