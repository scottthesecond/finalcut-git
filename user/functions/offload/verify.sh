#!/bin/bash

# Verify script for offloaded footage
# Usage: verify <source_path> [destination_path]





# Utility function to check if a file exists in a verify file
file_exists_in_verify() {
    local file_path="$1"
    local verify_file="$2"
    local filename=$(basename "$file_path")
    local parent_dir=$(basename "$(dirname "$file_path")")
    grep -q "/$parent_dir/$filename|" "$verify_file" 2>/dev/null
}



# Utility function to find all non-hidden files in a directory
find_all_files() {
    local path="$1"
    local exclude_pattern="$2"
    local files=()
    while IFS= read -r -d '' file; do
        # Skip hidden files (starting with .)
        if [[ ! "$(basename "$file")" =~ ^\. ]]; then
            # Skip files matching exclude pattern if provided
            if [ -z "$exclude_pattern" ] || [[ ! "$file" =~ $exclude_pattern ]]; then
                files+=("$file")
            fi
        fi
    done < <(find "$path" -type f -print0 2>/dev/null)
    printf '%s\0' "${files[@]}"
}

# Note: create_temp_file, cleanup_temp_files, and normalize_path are now in offload_file_utils.sh



# Note: calculate_hash() is now defined in offload_file_utils.sh

# Function to get file size
get_file_size() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to verify files using unified .offload file format
# Unified format: source_file|dest_file|new_filename|status|source_size|dest_size|source_hash|dest_hash
verify_files() {
    local source_path="$1"
    local destination_path="$2"
    local offload_file="$3"
    
    log_message "Verifying files using unified .offload file format"
    show_details "Verifying files using unified .offload file format"
    
    local total_files=$(wc -l < "$offload_file")
    local current_file=0
    local verified_count=0
    local failed_count=0
    
    # Create temporary file for updated offload file
    local temp_offload=$(create_temp_file "offload_update")
    > "$temp_offload"
    
    show_details "Starting verification of $total_files files..."
    show_progress 10
    
    # Define a callback function for processing each entry
    process_verify_entry() {
        local line_number="$1"
        local source_file="$2"
        local dest_file="$3"
        local new_filename="$4"
        local status="$5"
        local source_size="$6"
        local dest_size="$7"
        local source_hash="$8"
        local dest_hash="$9"
        
        ((current_file++))
        
        # Calculate progress percentage (10-90% range for verification phase)
        local progress=$(calculate_progress $current_file $total_files 10 80)
        show_progress $progress
        
        log_message "Verifying file $current_file/$total_files: $new_filename"
        show_details "Verifying file $current_file/$total_files..."
        
        # Check if source file exists
        if ! check_source_file_exists "$source_file" "$new_filename"; then
            write_offload_entry "$temp_offload" "$source_file" "$dest_file" "$new_filename" "$STATUS_FAILED" "0" "0" "" ""
            ((failed_count++))
            return
        fi
        
        # Check if destination file exists
        if ! check_dest_file_exists "$dest_file" "$new_filename"; then
            write_offload_entry "$temp_offload" "$source_file" "$dest_file" "$new_filename" "$STATUS_FAILED" "0" "0" "" ""
            ((failed_count++))
            return
        fi
        
        # Calculate source file hash and size
        log_message "Calculating source file hash..."
        local current_source_hash
        if ! current_source_hash=$(calculate_hash "$source_file"); then
            log_message "ERROR: Failed to calculate source hash for $new_filename"
            local current_source_size=$(get_file_size "$source_file")
            write_offload_entry "$temp_offload" "$source_file" "$dest_file" "$new_filename" "$STATUS_FAILED" "$current_source_size" "0" "" ""
            ((failed_count++))
            return
        fi
        local current_source_size=$(get_file_size "$source_file")
        
        # Calculate destination file hash and size
        log_message "Calculating destination file hash..."
        local current_dest_hash
        if ! current_dest_hash=$(calculate_hash "$dest_file"); then
            log_message "ERROR: Failed to calculate destination hash for $new_filename"
            local current_dest_size=$(get_file_size "$dest_file")
            write_offload_entry "$temp_offload" "$source_file" "$dest_file" "$new_filename" "$STATUS_FAILED" "$current_source_size" "$current_dest_size" "$current_source_hash" ""
            ((failed_count++))
            return
        fi
        local current_dest_size=$(get_file_size "$dest_file")
        
        # Verify sizes match
        if ! compare_file_sizes "$current_source_size" "$current_dest_size" "$source_file" "$dest_file"; then
            write_offload_entry "$temp_offload" "$source_file" "$dest_file" "$new_filename" "$STATUS_FAILED" "$current_source_size" "$current_dest_size" "$current_source_hash" "$current_dest_hash"
            ((failed_count++))
            return
        fi
        
        # Verify hashes match
        if ! compare_file_hashes "$current_source_hash" "$current_dest_hash" "$source_file" "$dest_file"; then
            write_offload_entry "$temp_offload" "$source_file" "$dest_file" "$new_filename" "$STATUS_FAILED" "$current_source_size" "$current_dest_size" "$current_source_hash" "$current_dest_hash"
            ((failed_count++))
            return
        fi
        
        # Update status to verified with current hash/size data
        write_offload_entry "$temp_offload" "$source_file" "$dest_file" "$new_filename" "$STATUS_VERIFIED" "$current_source_size" "$current_dest_size" "$current_source_hash" "$current_dest_hash"
        
        log_message "✓ Verified: $new_filename (size: $current_source_size, hash: ${current_source_hash:0:8}...)"
        show_details "✓ Verified: $new_filename"
        ((verified_count++))
    }
    
    # Process the offload file using the utility function
    read_offload_file "$offload_file" "process_verify_entry"
    
    # Replace offload file with updated version
    # Handle permission issues on external drives (like SD cards)
    if ! mv "$temp_offload" "$offload_file" 2>/dev/null; then
        # If mv fails due to permissions, try cp then rm
        if cp "$temp_offload" "$offload_file" 2>/dev/null; then
            rm -f "$temp_offload" 2>/dev/null
            log_message "Used cp+rm instead of mv due to permission restrictions"
        else
            log_message "ERROR: Failed to update offload file due to permission restrictions"
            # Continue with the temp file for now
            offload_file="$temp_offload"
        fi
    fi
    
    # If this was a source .offload file, also update the destination .offload file
    if [ "$(dirname "$offload_file")" = "$source_path" ]; then
        local dest_offload_file="$destination_path/.offload"
        if [ -f "$dest_offload_file" ]; then
            log_message "Updating destination .offload file with verification results"
            cp "$offload_file" "$dest_offload_file"
        fi
    fi
    
    show_progress 100
    show_details "Verification complete!"
    show_details "Total files: $total_files"
    show_details "Verified: $verified_count"
    if [ "$failed_count" -gt 0 ]; then
        show_details "Failed: $failed_count"
    fi
    
    log_message "Verification complete!"
    log_message "Total files: $total_files"
    log_message "Verified: $verified_count"
    log_message "Failed: $failed_count"
    
    # Generate verification report
    local temp_matched=$(create_temp_file "verify_matched")
    local temp_unmatched=$(create_temp_file "verify_unmatched")
    > "$temp_matched"
    > "$temp_unmatched"
    
    # Create summary files for report generation
    while IFS='|' read -r source_file dest_file new_filename status source_size dest_size source_hash dest_hash; do
        if [ "$status" = "verified" ]; then
            echo "✓ $new_filename" >> "$temp_matched"
        else
            echo "❌ $new_filename" >> "$temp_unmatched"
        fi
    done < "$offload_file"
    
    # Create a simple report for .offload-based verification
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local source_name=$(basename "$source_path" | tr ' ' '_')
    local report_file="$destination_path/verification_report_${source_name}_${timestamp}.txt"
    
    # Get skipped files information from .ignore file
    local ignore_file="$source_path/.ignore"
    local skipped_files_count=0
    
    if [ -f "$ignore_file" ]; then
        skipped_files_count=$(wc -l < "$ignore_file" 2>/dev/null || echo "0")
    fi
    
    {
        echo "# Verification Report - $(basename "$source_path") - $(date)"
        echo ""
        echo "## Summary"
        echo "- Source: $source_path"
        echo "- Destination: $destination_path"
        echo "- Total files: $total_files"
        echo "- Files verified: $verified_count"
        echo "- Files failed: $failed_count"
        echo "- Files intentionally skipped: $skipped_files_count"
        if [ "$total_files" -gt 0 ]; then
            local success_percentage=$((verified_count * 100 / total_files))
            echo "- Verification status: ${success_percentage}% Complete"
        fi
        echo ""
        
        if [ "$verified_count" -gt 0 ]; then
            echo "## Verified Files"
            cat "$temp_matched"
            echo ""
        fi
        
        if [ "$failed_count" -gt 0 ]; then
            echo "## Failed Files"
            cat "$temp_unmatched"
            echo ""
        fi
        
        if [ "$skipped_files_count" -gt 0 ]; then
            echo "## Skipped Files"
            echo "The following files were intentionally skipped during offload:"
            echo ""
            while IFS='|' read -r skipped_file reason; do
                echo "- $(basename "$skipped_file"): $reason"
            done < "$ignore_file"
            echo ""
        fi
        
        echo "## Recommendations"
        if [ "$failed_count" -gt 0 ]; then
            echo "- Check failed files for corruption or missing data"
            echo "- Re-transfer failed files if necessary"
        else
            echo "- All files verified successfully"
            echo "- Card can be formatted safely"
        fi
        echo ""
        echo "Report generated: $(date)"
    } > "$report_file"
    
    log_message "Verification report saved: $report_file"
    show_details "Report saved: $(basename "$report_file")"
    
    # Prompt for user action
    local action=$(prompt_verification_action "$failed_count" "$report_file")
    
    case "$action" in
        "Transfer Missing Files")
            transfer_missing_files "$source_path" "$destination_path" "$temp_unmatched"
            ;;
        "Format Card")
            format_source "$source_path"
            ;;
        "Full Reverify")
            full_reverify "$source_path" "$destination_path"
            ;;
        "Done")
            log_message "User chose to finish verification"
            ;;
        *)
            log_message "Unknown action: $action"
            ;;
    esac
    
    # Cleanup temporary files
    rm -f "$temp_matched" "$temp_unmatched"
    
    echo "Verification complete! $verified_count/$total_files files verified successfully."
}

# Function to prepare destination hashes
# Creates a .verify file in the destination with all file hashes
prepare_destination_hashes() {
    local destination_path="$1"
    local verify_file="$destination_path/.verify"
    
    log_message "Preparing destination hashes in: $verify_file"
    show_details "Preparing to verify..."
    
    # Create verify file if it doesn't exist (don't clear existing)
    if [ ! -f "$verify_file" ]; then
        > "$verify_file"
    fi
    
    log_message "Finding and extracting hashes from .offload files"
    
    # Find all .offload files in one pass
    local offload_files=()
    while IFS= read -r -d '' offload_file; do
        offload_files+=("$offload_file")
    done < <(find "$destination_path" -name ".offload" -print0 2>/dev/null)
    
    local total_offload_files=${#offload_files[@]}
    log_message "Found $total_offload_files .offload files"
    
    # Extract hashes from all .offload files
    local current_offload=0
    for offload_file in "${offload_files[@]}"; do
        ((current_offload++))
        local progress=$(calculate_progress $current_offload $total_offload_files 5 10)
        show_progress $progress
        
        local subdir_name=$(basename "$(dirname "$offload_file")")
        log_message "Processing .offload file: $subdir_name"
        
        # Extract hashes from .offload file using utility function
        process_offload_entry() {
            local line_number="$1"
            local source_file="$2"
            local dest_file="$3"
            local new_filename="$4"
            local status="$5"
            local source_size="$6"
            local dest_size="$7"
            local source_hash="$8"
            local dest_hash="$9"
            
            if [ -f "$dest_file" ]; then
                # Check if we already have this file in .verify
                if ! file_exists_in_verify "$dest_file" "$verify_file"; then
                    if [ -n "$dest_hash" ] && [ "$dest_hash" != "" ]; then
                        # Use existing hash from .offload file (new format)
                        write_verify_entry "$verify_file" "$dest_file" "$dest_hash" "$dest_size"
                        log_message "Added hash from .offload: $(basename "$dest_file")"
                    else
                        # File exists but no hash in .offload (old format), calculate new one
                        show_details "Calculating hash for: $(basename "$dest_file")"
                        local new_hash
                        if new_hash=$(calculate_hash "$dest_file"); then
                            local new_size=$(get_file_size "$dest_file")
                            write_verify_entry "$verify_file" "$dest_file" "$new_hash" "$new_size"
                            log_message "Calculated new hash: $(basename "$dest_file")"
                        else
                            log_message "ERROR: Failed to calculate hash for $(basename "$dest_file")"
                        fi
                    fi
                else
                    log_message "File already in .verify: $(basename "$dest_file")"
                fi
            fi
        }
        
        read_offload_file "$offload_file" "process_offload_entry"
    done
    
    # STEP 2: Find all files and identify missing ones
    log_message "Step 2: Finding all files and identifying missing hashes"
    show_details "Checking destination verification database..."
    
    # Get all files in destination recursively (excluding hidden files and .offload files)
    local all_files=()
    while IFS= read -r -d '' file; do
        all_files+=("$file")
    done < <(find_all_files "$destination_path" "\.offload$")
    local total_files=${#all_files[@]}
    log_message "Found $total_files total files in destination"
    
    # Create a temporary file with all files that need hashing
    local temp_missing=$(create_temp_file "missing_hashes")
    > "$temp_missing"
    
    # Check which files are missing from .verify
    local missing_count=0
    for file_path in "${all_files[@]}"; do
        if ! file_exists_in_verify "$file_path" "$verify_file"; then
            echo "$file_path" >> "$temp_missing"
            ((missing_count++))
        fi
    done
    
    log_message "Found $missing_count files missing from .verify"
    show_details "Found $missing_count files on the destination missing from verification database, I will now calculate the hashes for them."
    
    # STEP 3: Calculate hashes for missing files
    if [ "$missing_count" -gt 0 ]; then
        log_message "Step 3: Calculating hashes for missing files"
        
        local current_file=0
        while IFS= read -r file_path; do
            ((current_file++))
            local progress=$(calculate_progress $current_file $missing_count 15 80)
            show_progress $progress
            
            show_details "Rebuilding verification database ($current_file/$missing_count: $(basename "$file_path"))"
            local file_hash
            if file_hash=$(calculate_hash "$file_path"); then
                local file_size=$(get_file_size "$file_path")
                local normalized_path=$(normalize_path "$file_path")
                write_verify_entry "$verify_file" "$normalized_path" "$file_hash" "$file_size"
                log_message "Calculated hash for: $(basename "$file_path")"
            else
                log_message "ERROR: Failed to calculate hash for $(basename "$file_path")"
            fi
        done < "$temp_missing"
    else
        log_message "No files missing from .verify"
        show_details "Verification database is OK."
    fi
    
    # Clean up temp file
    rm -f "$temp_missing"
    
    local total_hashes=$(wc -l < "$verify_file")
    log_message "Destination hash preparation complete. Total files: $total_hashes"
    show_progress 95
    
    echo "$total_hashes"
}

# Function to prepare source hashes (ensure all files have hashes)
prepare_source_hashes() {
    local source_path="$1"
    local source_hashes_file="$2"
    
    log_message "Preparing source hashes in: $source_hashes_file"
    show_details "Preparing source hashes..."
    
    # Create source .verify file if it doesn't exist (don't clear existing)
    local source_verify_file="$source_path/.verify"
    if [ ! -f "$source_verify_file" ]; then
        > "$source_verify_file"
    fi
    
    # STEP 1: Extract hashes from .offload file first
    log_message "Step 1: Extracting hashes from .offload file"
    show_details "Checking source verification database..."
    
    local source_offload_file="$source_path/.offload"
    if [ -f "$source_offload_file" ]; then
        log_message "Found source .offload file, extracting existing hashes"
        #show_details "Extracting existing hashes from .offload file"
        
        # Extract existing hashes from .offload file using utility function
        process_source_offload_entry() {
            local line_number="$1"
            local source_file="$2"
            local dest_file="$3"
            local new_filename="$4"
            local status="$5"
            local source_size="$6"
            local dest_size="$7"
            local source_hash="$8"
            local dest_hash="$9"
            
            if [ -f "$source_file" ]; then
                # Check if we already have this file in .verify
                if ! file_exists_in_verify "$source_file" "$source_verify_file"; then
                    if [ -n "$source_hash" ] && [ "$source_hash" != "" ]; then
                        write_verify_entry "$source_verify_file" "$source_file" "$source_hash" "$source_size"
                        write_verify_entry "$source_hashes_file" "$source_file" "$source_hash" "$source_size"
                        log_message "Using existing hash for: $(basename "$source_file")"
                    else
                        local new_hash
                        if new_hash=$(calculate_hash "$source_file"); then
                            local new_size=$(get_file_size "$source_file")
                            write_verify_entry "$source_verify_file" "$source_file" "$new_hash" "$new_size"
                            write_verify_entry "$source_hashes_file" "$source_file" "$new_hash" "$new_size"
                            log_message "Calculated new hash for: $(basename "$source_file")"
                        else
                            log_message "ERROR: Failed to calculate hash for $(basename "$source_file")"
                        fi
                    fi
                else
                    log_message "File already in .verify: $(basename "$source_file")"
                    # Still add to source_hashes_file for processing
                    local filename=$(basename "$source_file")
                    local parent_dir=$(basename "$(dirname "$source_file")")
                    local existing_line=$(grep "/$parent_dir/$filename|" "$source_verify_file" 2>/dev/null)
                    if [ -n "$existing_line" ]; then
                        echo "$existing_line" >> "$source_hashes_file"
                    fi
                fi
            fi
        }
        
        read_offload_file "$source_offload_file" "process_source_offload_entry"
    fi
    
    # STEP 2: Find all files and identify missing ones
    log_message "Step 2: Finding all files and identifying missing hashes"
    #show_details "Re-scanning source for missing files..."
    
    # Get all files in source (excluding hidden files)
    local all_files=()
    while IFS= read -r -d '' file; do
        all_files+=("$file")
    done < <(find_all_files "$source_path")
    local total_files=${#all_files[@]}
    log_message "Found $total_files total files in source"
    #show_details "Found $total_files total files in source"
    
    # Create a temporary file with all files that need hashing
    local temp_missing=$(create_temp_file "missing_source_hashes")
    > "$temp_missing"
    
    # Check which files are missing from .verify
    local missing_count=0
    for file_path in "${all_files[@]}"; do
        if ! file_exists_in_verify "$file_path" "$source_verify_file"; then
            echo "$file_path" >> "$temp_missing"
            ((missing_count++))
        fi
    done
    
    log_message "Found $missing_count files missing from source .verify"
    #show_details "Found $missing_count files missing from source .verify"
    
    # STEP 3: Calculate hashes for missing files
    if [ "$missing_count" -gt 0 ]; then
        log_message "Step 3: Calculating hashes for missing files"
        show_details "Rebuilding source verification database..."
        
        local current_file=0
        while IFS= read -r file_path; do
            ((current_file++))
            local progress=$(calculate_progress $current_file $missing_count 15 80)
            show_progress $progress

            show_details "Rebuilding source verification database ($current_file/$missing_count: $(basename "$file_path"))"

            #show_details "Calculating hash for: $current_file/$missing_count: $(basename "$file_path")"
            local file_hash
            if file_hash=$(calculate_hash "$file_path"); then
                local file_size=$(get_file_size "$file_path")
                local normalized_path=$(normalize_path "$file_path")
                write_verify_entry "$source_verify_file" "$normalized_path" "$file_hash" "$file_size"
                write_verify_entry "$source_hashes_file" "$normalized_path" "$file_hash" "$file_size"
                log_message "Calculated hash for: $(basename "$file_path")"
            else
                log_message "ERROR: Failed to calculate hash for $(basename "$file_path")"
            fi
        done < "$temp_missing"
    else
        log_message "No files missing from source .verify"
        show_details "No files missing from source .verify"
    fi
    
    # Add all existing files to source_hashes_file for processing
    if [ -f "$temp_missing" ] && [ -s "$temp_missing" ]; then
        while IFS= read -r file_path; do
            local existing_line=$(grep "^$file_path|" "$source_verify_file" 2>/dev/null)
            if [ -n "$existing_line" ]; then
                echo "$existing_line" >> "$source_hashes_file"
            fi
        done < "$temp_missing"
    fi
    
    # Clean up temp file
    rm -f "$temp_missing"
    
    local total_hashes=$(wc -l < "$source_verify_file")
    log_message "Source hash preparation complete. Total files: $total_hashes"
    show_details "Source hash preparation complete: $total_hashes files"
    
    echo "$total_hashes"
}

# Function to check if source .verify file is complete and up-to-date
check_source_verify_file_completeness() {
    local source_path="$1"
    local verify_file="$2"
    
    log_message "Checking source .verify file completeness..."
    
    # Get list of all files in source (handle paths with spaces properly)
    local all_files=()
    while IFS= read -r -d '' file; do
        all_files+=("$file")
    done < <(find "$source_path" -type f -print0 2>/dev/null)
    local total_files=${#all_files[@]}
    
    if [ "$total_files" -eq 0 ]; then
        log_message "No files found in source, .verify file is not needed"
        return 1
    fi
    
    # Get list of files in .verify file
    local verify_files=($(cut -d'|' -f1 "$verify_file" 2>/dev/null))
    local verify_count=${#verify_files[@]}
    
    log_message "Total files in source: $total_files"
    log_message "Files in source .verify file: $verify_count"
    
    # Check if counts match
    if [ "$total_files" != "$verify_count" ]; then
        log_message "File count mismatch: $total_files vs $verify_count"
        return 1
    fi
    
    # Check if all files in source are in .verify file
    local missing_count=0
    for file in "${all_files[@]}"; do
        if ! grep -q "^$file|" "$verify_file" 2>/dev/null; then
            ((missing_count++))
            log_message "Missing from source .verify file: $file"
        fi
    done
    
    if [ "$missing_count" -gt 0 ]; then
        log_message "Found $missing_count files missing from source .verify file"
        return 1
    fi
    
    # Check if all files in .verify file still exist
    local non_existent_count=0
    for file in "${verify_files[@]}"; do
        if [ ! -f "$file" ]; then
            ((non_existent_count++))
            log_message "File in source .verify no longer exists: $file"
        fi
    done
    
    if [ "$non_existent_count" -gt 0 ]; then
        log_message "Found $non_existent_count files in source .verify that no longer exist"
        return 1
    fi
    
    log_message "Source .verify file is complete and up-to-date"
    return 0
}

# Function to check if .verify file is complete and up-to-date
check_verify_file_completeness() {
    local destination_path="$1"
    local verify_file="$2"
    
    log_message "Checking .verify file completeness..."
    
    # Get list of all files in destination subdirectories (handle paths with spaces properly)
    local all_files=()
    while IFS= read -r -d '' file; do
        all_files+=("$file")
    done < <(find "$destination_path" -type d -mindepth 1 -maxdepth 1 -exec find {} -type f -print0 \; 2>/dev/null)
    local total_files=${#all_files[@]}
    
    if [ "$total_files" -eq 0 ]; then
        log_message "No files found in destination, .verify file is not needed"
        return 1
    fi
    
    # Get list of files in .verify file
    local verify_files=($(cut -d'|' -f1 "$verify_file" 2>/dev/null))
    local verify_count=${#verify_files[@]}
    
    log_message "Total files in destination: $total_files"
    log_message "Files in .verify file: $verify_count"
    
    # Check if counts match
    if [ "$total_files" != "$verify_count" ]; then
        log_message "File count mismatch: $total_files vs $verify_count"
        return 1
    fi
    
    # Check if all files in destination are in .verify file
    local missing_count=0
    for file in "${all_files[@]}"; do
        if ! grep -q "^$file|" "$verify_file" 2>/dev/null; then
            ((missing_count++))
            log_message "Missing from .verify file: $file"
        fi
    done
    
    if [ "$missing_count" -gt 0 ]; then
        log_message "Found $missing_count files missing from .verify file"
        return 1
    fi
    
    # Check if all files in .verify file still exist
    local non_existent_count=0
    for file in "${verify_files[@]}"; do
        if [ ! -f "$file" ]; then
            ((non_existent_count++))
            log_message "File in .verify no longer exists: $file"
        fi
    done
    
    if [ "$non_existent_count" -gt 0 ]; then
        log_message "Found $non_existent_count files in .verify that no longer exist"
        return 1
    fi
    
    log_message ".verify file is complete and up-to-date"
    return 0
}

# Function to generate verification report
generate_verification_report() {
    local source_path="$1"
    local destination_path="$2"
    local matched_files="$3"
    local unmatched_files="$4"
    local verify_file="$destination_path/.verify"
    
    # Generate unique report filename
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local source_name=$(basename "$source_path" | tr ' ' '_')
    local report_file="$destination_path/verification_report_${source_name}_${timestamp}.txt"
    
    log_message "Generating verification report: $report_file"
    show_details "Generating verification report..."
    
    # Calculate statistics
    local total_source_files=$(wc -l < "$matched_files" 2>/dev/null || echo "0")
    local total_matched=$(grep -c "✓" "$matched_files" 2>/dev/null || echo "0")
    local total_unmatched=$(wc -l < "$unmatched_files" 2>/dev/null || echo "0")
    local total_dest_files=$(wc -l < "$verify_file")
    
    # Get skipped files information from .ignore file
    local ignore_file="$source_path/.ignore"
    local skipped_files_count=0
    local skipped_files_content=""
    
    if [ -f "$ignore_file" ]; then
        skipped_files_count=$(wc -l < "$ignore_file" 2>/dev/null || echo "0")
        if [ "$skipped_files_count" -gt 0 ]; then
            skipped_files_content=$(cat "$ignore_file" 2>/dev/null || echo "")
        fi
    fi
    
    # Create report
    {
        echo "# Verification Report - $(basename "$source_path") - $(date)"
        echo ""
        echo "## Summary"
        echo "- Source: $source_path"
        echo "- Destination: $destination_path"
        echo "- Total files on source: $total_source_files"
        echo "- Files with matches: $total_matched"
        echo "- Files without matches: $total_unmatched"
        echo "- Files intentionally skipped: $skipped_files_count"
        echo "- Total files in destination: $total_dest_files"
        if [ "$total_source_files" -gt 0 ]; then
            local match_percentage=$((total_matched * 100 / total_source_files))
            echo "- Verification status: ${match_percentage}% Complete"
        fi
        echo ""
        
        if [ "$total_matched" -gt 0 ]; then
            echo "## Matched Files"
            cat "$matched_files"
            echo ""
        fi
        
        if [ "$total_unmatched" -gt 0 ]; then
            echo "## Unmatched Files (Missing from Destination)"
            cat "$unmatched_files"
            echo ""
        fi
        
        if [ "$skipped_files_count" -gt 0 ]; then
            echo "## Skipped Files"
            echo "The following files were intentionally skipped during offload:"
            echo ""
            while IFS='|' read -r skipped_file reason; do
                echo "- $(basename "$skipped_file"): $reason"
            done < "$ignore_file"
            echo ""
        fi
        
        echo "## Recommendations"
        if [ "$total_unmatched" -gt 0 ]; then
            echo "- Transfer $total_unmatched missing files to destination"
            echo "- Card can be formatted after transfer"
        else
            echo "- All files verified successfully"
            echo "- Card can be formatted safely"
        fi
        echo ""
        echo "Report generated: $(date)"
    } > "$report_file"
    
    log_message "Verification report saved: $report_file"
    show_details "Report saved: $(basename "$report_file")"
    
    # Return the report file path (this must be the last output)
    printf "%s" "$report_file"
}

# Function to verify external card/source
verify_external_source() {
    local source_path="$1"
    local destination_path="$2"
    
    log_message "Starting external source verification"
    log_message "Source: $source_path"
    log_message "Destination: $destination_path"
    
    # Show initial progress and details
    show_progress 5
    show_details_on
    show_details "Starting external verification..."
    show_details "Source: $(basename "$source_path")"
    show_details "Destination: $(basename "$destination_path")"
    
    # Validate parameters
    if [ -z "$source_path" ] || [ ! -d "$source_path" ]; then
        handle_error "Invalid source path: $source_path"
    fi
    
    if [ -z "$destination_path" ] || [ ! -d "$destination_path" ]; then
        handle_error "Invalid destination path: $destination_path"
    fi
    
    # Step 1: Prepare destination hashes
    #show_details "Step 1: Preparing destination hashes..."
    prepare_destination_hashes "$destination_path"
    
    # Get the count from the .verify file
    local verify_file="$destination_path/.verify"
    local total_dest_files=$(wc -l < "$verify_file" 2>/dev/null || echo "0")
    
    if [ "$total_dest_files" -eq 0 ]; then
        handle_error "No files found in destination directory"
    fi
    
    # Step 2: Calculate source file hashes and compare
    show_details "Step 2: Calculating source hashes and comparing..."
    show_progress 25
    
    local temp_matched=$(create_temp_file "verify_matched")
    local temp_unmatched=$(create_temp_file "verify_unmatched")
    > "$temp_matched"
    > "$temp_unmatched"
    
    # Step 1: Prepare source hashes (ensure all files have hashes)
    show_details "Step 1: Preparing source hashes..."
    local source_hashes_file=$(create_temp_file "source_hashes")
    > "$source_hashes_file"
    
    prepare_source_hashes "$source_path" "$source_hashes_file"
    local total_source_hashes=$(wc -l < "$source_hashes_file")
    log_message "Prepared $total_source_hashes source hashes"
    
    # Step 2: Filter files using only .ignore file
    show_details "Step 2: Filtering files using .ignore file..."
    local ignore_file="$source_path/.ignore"
    local ignored_files_file=$(create_temp_file "ignored_files")
    > "$ignored_files_file"
    
    if [ -f "$ignore_file" ]; then
        log_message "Found .ignore file, reading skipped files"
        show_details "Reading list of intentionally skipped files"
        
        # Read ignored files: file_path|reason
        while IFS='|' read -r ignored_file reason; do
            echo "$ignored_file" >> "$ignored_files_file"
        done < "$ignore_file"
        
        log_message "Found $(wc -l < "$ignored_files_file") intentionally skipped files"
    fi
    
    # Get list of files to verify (all files with hashes, minus ignored files)
    local source_files=($(cut -d'|' -f1 "$source_hashes_file"))
    local filtered_files=()
    local ignored_count=0
    
    for file in "${source_files[@]}"; do
        # Skip files in .ignore file
        if [ -f "$ignored_files_file" ] && grep -Fxq "$file" "$ignored_files_file" 2>/dev/null; then
            ((ignored_count++))
            log_message "Skipping verification of $(basename "$file"): Intentionally skipped during offload"
        else
            filtered_files+=("$file")
        fi
    done
    
    local total_source_files=${#filtered_files[@]}
    local current_file=0
    local matched_count=0
    local unmatched_count=0
    local cached_hash_count=0
    local calculated_hash_count=0
    
    log_message "Found ${#source_files[@]} total files with hashes"
    log_message "Filtered to $total_source_files files for verification (ignored $ignored_count files)"
    show_details "Found $total_source_files files to verify (ignored $ignored_count intentionally skipped files)"
    
    if [ -z "$total_source_files" ] || [ "$total_source_files" -eq 0 ]; then
        total_source_files=1
    fi

    for source_file in "${filtered_files[@]}"; do
        ((current_file++))
        local progress=$(calculate_progress $current_file $total_source_files 25 60)
        show_progress $progress
        
        local filename=$(basename "$source_file")
        log_message "Processing file $current_file/$total_source_files: $filename"
        show_details "Verifying: $filename"
        
        # Get source hash from pre-calculated hashes
        local source_hash=""
        local source_size=""
        
        # Look for hash in source_hashes_file
        while IFS='|' read -r stored_file stored_hash stored_size; do
            if [ "$stored_file" = "$source_file" ]; then
                source_hash="$stored_hash"
                source_size="$stored_size"
                break
            fi
        done < "$source_hashes_file"
        
        if [ -z "$source_hash" ]; then
            log_message "ERROR: Could not find hash for $filename in prepared hashes"
            show_details "✗ Could not find hash for $filename"
            echo "❌ $filename (Hash not found)" >> "$temp_unmatched"
            ((unmatched_count++))
            continue
        fi
        
        #show_details "Ver: $filename (using prepared hash)"
        
        # Look for matching hash in destination
        local match_found=false
        while IFS='|' read -r dest_file dest_hash dest_size; do
            if [ "$source_hash" = "$dest_hash" ]; then
                # Found a match by hash, now check if the destination file's current hash matches the stored hash
                if [ -f "$dest_file" ]; then
                    local current_dest_hash
                    if current_dest_hash=$(calculate_hash "$dest_file"); then
                                                if [ "$current_dest_hash" = "$dest_hash" ]; then
                            # File matches and is unmodified
                            local dest_filename=$(basename "$dest_file")
                            local dest_subdir=$(basename "$(dirname "$dest_file")")
                            echo "✓ $filename → $dest_subdir/$dest_filename" >> "$temp_matched"
                            log_message "✓ Matched: $filename → $dest_subdir/$dest_filename"
                            show_details "✓ Matched: $filename"
                            match_found=true
                            ((matched_count++))
                            break
                        else
                            # File has been modified since .verify was created
                            echo "❌ $filename (Destination file modified)" >> "$temp_unmatched"
                            log_message "❌ Destination file modified: $dest_file"
                            show_details "❌ Modified: $filename"
                            match_found=true
                            ((unmatched_count++))
                            break
                        fi
                    else
                        # Hash calculation failed
                        echo "❌ $filename (Hash calculation failed)" >> "$temp_unmatched"
                        log_message "❌ Hash calculation failed for destination file: $dest_file"
                        show_details "❌ Hash failed: $filename"
                        match_found=true
                        ((unmatched_count++))
                        break
                    fi
                fi
            fi
        done < "$verify_file"
        
        if [ "$match_found" = false ]; then
            echo "❌ $filename ($(format_file_size "$source_size"))" >> "$temp_unmatched"
            log_message "❌ No match found for $filename"
            show_details "❌ No match: $filename"
            ((unmatched_count++))
        fi
    done
    
    # Log verification statistics
    log_message "Verification processing complete"
    show_details "Verification processing complete"
    
    # Cleanup temporary files
    rm -f "$source_hashes_file" "$ignored_files_file"
    
    # Step 3: Generate verification report
    show_details "Step 3: Generating verification report..."
    show_progress 90
    
    local report_file=$(generate_verification_report "$source_path" "$destination_path" "$temp_matched" "$temp_unmatched")
    
    # Step 4: Show results and prompt for action
    show_progress 100
    show_details "Verification complete!"
    show_details "Total files: $total_source_files"
    show_details "Matched: $matched_count"
    if [ "$unmatched_count" -gt 0 ]; then
        show_details "Unmatched: $unmatched_count"
    fi
    
    log_message "External verification complete!"
    log_message "Total files: $total_source_files"
    log_message "Matched: $matched_count"
    log_message "Unmatched: $unmatched_count"
    
    if [ -f "$report_file" ]; then
        open "$report_file"
    else
        log_message "Report file not found: $report_file"
    fi
    
    # Prompt for user action
    local action=$(prompt_verification_action "$unmatched_count" "$report_file")
    
    case "$action" in
        "Transfer Missing Files")
            transfer_missing_files "$source_path" "$destination_path" "$temp_unmatched"
            ;;
        "Format Card")
            format_source "$source_path"
            ;;
        "Full Reverify")
            full_reverify "$source_path" "$destination_path"
            ;;
        "Done")
            log_message "User chose to finish verification"
            ;;
        *)
            log_message "Unknown action: $action"
            ;;
    esac
    
    # Cleanup temporary files
    rm -f "$temp_matched" "$temp_unmatched"
    
    echo "External verification complete! $matched_count/$total_source_files files matched."
    echo "\n===== VERIFICATION SUMMARY ====="
    echo "Source: $source_path"
    echo "Destination: $destination_path"
    echo "Total files: $total_source_files"
    echo "Matched: $matched_count"
    echo "Unmatched: $unmatched_count"
    echo "Report: $report_file"
    echo "================================\n"
}

# Function to format file size for display
format_file_size() {
    local size="$1"
    if [ -z "$size" ] || [ "$size" -eq 0 ]; then
        echo "0 B"
        return
    fi
    
    local units=("B" "KB" "MB" "GB" "TB")
    local unit_index=0
    local size_float=$size
    
    while [ "$size_float" -ge 1024 ] && [ $unit_index -lt 4 ]; do
        size_float=$((size_float / 1024))
        ((unit_index++))
    done
    
    echo "${size_float} ${units[$unit_index]}"
}

# Function to prompt for verification action
prompt_verification_action() {
    local unmatched_count="$1"
    local report_file="$2"
    
    log_message "Prompting for verification action with unmatched_count: $unmatched_count"
    
    # Build the message with proper line breaks using printf
    local message
    if [ "$unmatched_count" -gt 0 ]; then
        message=$(printf "Verification complete!\n\nFound %d files without matches.\nWhat would you like to do?" "$unmatched_count")
    else
        message=$(printf "Verification complete!\n\nAll files verified successfully!\nWould you like to format the card now?")
    fi
    
    # Escape special characters for osascript (but preserve line breaks)
    message=$(echo "$message" | sed 's/"/\\"/g' | sed "s/'/\\'/g")
    
    # Build the osascript command with proper button syntax
    local osascript_cmd
    if [ "$unmatched_count" -gt 0 ]; then
        # For failed verifications: Transfer, Reverify, Open Report, Done (4 buttons)
        osascript_cmd="display dialog \"$message\" buttons {\"Transfer Missing Files\", \"Full Reverify\", \"Open Report\", \"Done\"} default button \"Done\" with title \"Verification Complete\""
    else
        # For successful verifications: Format Card, Open Report, Done (3 buttons)
        osascript_cmd="display dialog \"$message\" buttons {\"Format Card\", \"Open Report\", \"Done\"} default button \"Done\" with title \"Verification Complete\""
    fi
    
    log_message "Showing dialog with message: $message"
    
    # Run osascript and capture both output and error
    result=$(osascript -e "$osascript_cmd" 2>&1)
    osascript_status=$?
    
    # Check if osascript failed
    if [ $osascript_status -ne 0 ]; then
        log_message "Error: Failed to display verification action dialog. Status: $osascript_status, Error: $result"
        printf "%s" "Done"
        return
    fi
    
    # Parse the result
    local choice=$(echo "$result" | sed -n 's/.*button returned:\(.*\)/\1/p' | tr -d ', ')
    
    log_message "Dialog returned choice: '$choice'"
    
    # Handle "Open Report" choice
    if [ "$choice" = "Open Report" ] && [ -n "$report_file" ] && [ -f "$report_file" ]; then
        log_message "Opening verification report: $report_file"
        open "$report_file"
        
        # Show the prompt again after opening the report
        sleep 1  # Brief pause to let the report open
        prompt_verification_action "$unmatched_count" "$report_file"
        return
    fi
    
    printf "%s" "$choice"
}

# Function to transfer missing files
transfer_missing_files() {
    local source_path="$1"
    local destination_path="$2"
    local unmatched_file="$3"
    
    log_message "Starting transfer of missing files"
    show_details "Transferring missing files..."
    
    # Prompt for destination subfolder
    local dest_subfolder=$(prompt_destination_subfolder "$destination_path")
    if [ -z "$dest_subfolder" ]; then
        log_message "User cancelled transfer"
        return
    fi
    
    local transfer_dest="$destination_path/$dest_subfolder"
    mkdir -p "$transfer_dest"
    
    # Transfer files
    local transferred_count=0
    while IFS=' ' read -r status filename size; do
        if [ "$status" = "❌" ]; then
            # Remove the size part from filename (it's in parentheses)
            local clean_filename=$(echo "$filename" | sed 's/(.*)$//')
            local source_file="$source_path/$clean_filename"
            local dest_file="$transfer_dest/$clean_filename"
            
            if [ -f "$source_file" ]; then
                log_message "Transferring: $clean_filename"
                show_details "Transferring: $clean_filename"
                cp "$source_file" "$dest_file"
                ((transferred_count++))
            fi
        fi
    done < "$unmatched_file"
    
    log_message "Transfer complete: $transferred_count files transferred to $transfer_dest"
    show_details "Transfer complete: $transferred_count files"
    
    # Update .verify file with new files
    for file in "$transfer_dest"/*; do
        if [ -f "$file" ]; then
            local file_hash
            if file_hash=$(calculate_hash "$file"); then
                local file_size=$(get_file_size "$file")
                write_verify_entry "$destination_path/.verify" "$file" "$file_hash" "$file_size"
            else
                log_message "ERROR: Failed to calculate hash for transferred file: $(basename "$file")"
            fi
        fi
    done
}

# Function to prompt for destination subfolder
prompt_destination_subfolder() {
    local destination_path="$1"
    
    # Get existing subfolders
    local subfolders=($(find "$destination_path" -type d -mindepth 1 -maxdepth 1 -exec basename {} \;))
    
    # Build the osascript command
    local osascript_cmd='display dialog "Enter destination subfolder name for missing files:" default answer "new_files" buttons {"Cancel", "OK"} default button "OK" with title "Transfer Destination"'
    
    # Run osascript and capture both output and error
    result=$(osascript -e "$osascript_cmd" 2>&1)
    osascript_status=$?
    
    # Check if osascript failed
    if [ $osascript_status -ne 0 ]; then
        log_message "Error: Failed to display destination subfolder dialog. Status: $osascript_status, Error: $result"
        echo ""
        return
    fi
    
    # Parse the result
    button_clicked=$(echo "$result" | sed -n 's/.*button returned:\(.*\), text returned.*/\1/p' | tr -d ', ')
    folder_name=$(echo "$result" | sed -n 's/.*text returned:\(.*\)/\1/p' | tr -d ', ')
    
    if [ "$button_clicked" = "Cancel" ]; then
        log_message "User canceled destination subfolder dialog"
        echo ""
        return
    fi
    
    echo "$folder_name"
}

# Function to format source (placeholder)
format_source() {
    local source_path="$1"
    
    log_message "Formatting source: $source_path"
    show_details "Formatting source..."
    
    # This is a placeholder - actual formatting would depend on the source type
    # For now, just show a message
    local osascript_cmd='display dialog "Format functionality not yet implemented.\n\nPlease format the card manually." buttons {"OK"} default button "OK" with title "Format Card"'
    
    # Run osascript and capture both output and error
    result=$(osascript -e "$osascript_cmd" 2>&1)
    osascript_status=$?
    
    # Check if osascript failed
    if [ $osascript_status -ne 0 ]; then
        log_message "Error: Failed to display format dialog. Status: $osascript_status, Error: $result"
    fi
}

# Function to perform full reverify
full_reverify() {
    local source_path="$1"
    local destination_path="$2"
    
    log_message "Performing full reverify"
    show_details "Performing full reverify..."
    
    # Remove existing .verify file to force complete recalculation
    local verify_file="$destination_path/.verify"
    if [ -f "$verify_file" ]; then
        log_message "Removing existing .verify file to force complete recalculation"
        rm -f "$verify_file"
    fi
    
    # Remove source .verify file to force re-hashing of all source files
    local source_verify_file="$source_path/.verify"
    if [ -f "$source_verify_file" ]; then
        log_message "Removing source .verify file to force re-hashing of all source files"
        show_details "Removing cached source hashes to force complete re-verification"
        rm -f "$source_verify_file"
    fi
    
    # Note: We keep .offload files intact - they contain valuable hash data
    # that we can reuse when rebuilding .verify files
    
    # Run verification again
    verify_external_source "$source_path" "$destination_path"
}

# Main verify function
verify() {
    local source_path="$1"
    local destination_path="$2"
    
    log_message "Starting verification process"
    log_message "Source: $source_path"
    log_message "Destination: $destination_path"
    
    # Show initial progress and details
    show_progress 5
    show_details_on
    show_details "Starting verification process..."
    show_details "Source: $(basename "$source_path")"
    if [ -n "$destination_path" ]; then
        show_details "Destination: $(basename "$destination_path")"
    fi
    
    # Validate parameters
    validate_verify_params "$source_path" "$destination_path"
    
    # Check for source .offload file
    local source_offload_file="$source_path/.offload"
    if [ -f "$source_offload_file" ]; then
        log_message "Found source .offload file: $source_offload_file"
        show_details "Found source .offload file"
        
        # Determine destination path from source .offload if not provided
        if [ -z "$destination_path" ]; then
            # Read first line to get destination path
            local first_line=$(head -n 1 "$source_offload_file")
            if [ -n "$first_line" ]; then
                IFS='|' read -r source_file dest_file new_filename status source_size dest_size source_hash dest_hash <<< "$first_line"
                destination_path=$(dirname "$dest_file")
                log_message "Extracted destination path from .offload file: $destination_path"
                show_details "Extracted destination path from .offload file"
            else
                handle_error "Cannot determine destination path from .offload file"
            fi
        fi
        
        verify_files "$source_path" "$destination_path" "$source_offload_file"
        
    else
        log_message "No source .offload file found"
        show_details "No source .offload file found"
        
        # Check if destination path is provided
        if [ -z "$destination_path" ]; then
            handle_error "Destination path required when no source .offload file exists"
        fi
        
        # Check for destination .offload file
        local dest_offload_file="$destination_path/.offload"
        if [ -f "$dest_offload_file" ]; then
            log_message "Found destination .offload file: $dest_offload_file"
            show_details "Found destination .offload file"
            verify_files "$source_path" "$destination_path" "$dest_offload_file"
        else
            handle_error "No .offload file found in source or destination"
        fi
    fi
} 