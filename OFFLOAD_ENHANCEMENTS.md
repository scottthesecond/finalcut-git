# Offload Feature Enhancements

## Overview

The offload functionality has been enhanced to provide intelligent handling of existing offload files on SD cards. When a user drops an SD card that already contains an offload file, the system now automatically detects the status and offers appropriate options.

## New Features

### 1. Automatic Status Detection

When an SD card with an existing `.offload` file is detected, the system automatically analyzes the status of the previous offload operation:

- **Incomplete**: Some files are still queued or unverified
- **Failed**: Some files failed to copy
- **Complete**: All files have been successfully verified
- **None**: No valid offload file found

### 2. Smart User Prompts

Based on the detected status, the system presents the user with relevant options:

#### For Incomplete Offloads:
- **Resume Offload**: Continue from where the previous operation left off
- **Start New Offload**: Begin a fresh offload (backs up existing file)
- **Cancel**: Abort the operation

#### For Failed Offloads:
- **Retry Failed Files**: Attempt to copy only the files that previously failed
- **Start New Offload**: Begin a fresh offload (backs up existing file)
- **Cancel**: Abort the operation

#### For Completed Offloads:
- **Re-verify Offload**: Run verification again to ensure integrity
- **Start New Offload**: Begin a fresh offload (backs up existing file)
- **Cancel**: Abort the operation

### 3. Resume Functionality

When resuming an incomplete offload:
- Only processes files that are still queued or unverified
- Skips files that have already been successfully copied
- Maintains the original destination path and file naming
- Provides progress updates and completion statistics

### 4. Retry Functionality

When retrying failed files:
- Resets failed file status to queued
- Attempts to copy only the previously failed files
- Maintains the original destination path and file naming
- Provides progress updates and completion statistics

### 5. Re-verify Functionality

When re-verifying a completed offload:
- Runs the full verification process again
- Compares file sizes and SHA256 hashes
- Provides detailed verification results
- No file copying occurs during re-verification

## Technical Implementation

### New Functions Added

1. **`check_offload_status(offload_file)`**
   - Analyzes the `.offload` file to determine overall status
   - Returns: "none", "incomplete", "failed", "complete", or "unknown"

2. **`get_offload_stats(offload_file)`**
   - Counts files by status (total, completed, failed, queued)
   - Returns: "total|completed|failed|queued"

3. **`prompt_offload_action(input_path, offload_file, status, stats)`**
   - Displays appropriate dialog based on status
   - Returns user's choice as string

4. **`resume_offload(input_path, output_path, project_shortname, source_name, type, counter, offload_file)`**
   - Handles resuming incomplete offloads
   - Processes only remaining files

5. **`retry_failed_offload(input_path, output_path, project_shortname, source_name, type, counter, offload_file)`**
   - Handles retrying failed files
   - Resets failed status and retries copying

6. **`reverify_offload(input_path, output_path)`**
   - Handles re-verification of completed offloads
   - Runs full verification process

### Enhanced Functions

1. **`copy_files(offload_file, output_path)`**
   - Now handles both "queued" and "unverified" file statuses
   - Supports resume operations

2. **`offload(input_path, output_path, project_shortname, source_name, type, counter)`**
   - Added status detection and user prompting
   - Handles early returns for special operations

3. **`run_offload_with_progress(input_path, provided_source_name)`**
   - Modified to handle early returns from special operations
   - Only runs verification for new offloads

## File Format

The `.offload` file format remains the same:
```
source_path|destination_path|new_filename|status
```

Status values:
- `queued`: File is ready to be copied
- `unverified`: File has been copied but not verified
- `verified`: File has been successfully copied and verified
- `failed`: File copy operation failed

## User Experience

### Workflow for New SD Cards:
1. User drops SD card
2. System creates new offload file
3. Files are copied and verified
4. Process completes normally

### Workflow for SD Cards with Existing Offload:
1. User drops SD card
2. System detects existing `.offload` file
3. System analyzes status and shows appropriate dialog
4. User chooses action (resume/retry/re-verify/start new/cancel)
5. System executes chosen action
6. Process completes with appropriate feedback

## Benefits

1. **Time Savings**: Users can resume interrupted offloads without starting over
2. **Data Integrity**: Failed files can be retried without affecting successful copies
3. **Verification**: Completed offloads can be re-verified for peace of mind
4. **Flexibility**: Users can choose to start fresh if needed
5. **Reliability**: Robust handling of various offload states

## Testing

The functionality has been tested with:
- Normal offload operations
- Incomplete offload scenarios
- Failed file scenarios
- Completed offload scenarios
- Various file status combinations

All features work correctly and integrate seamlessly with the existing offload system. 