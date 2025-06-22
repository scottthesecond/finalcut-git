#!/bin/bash

# Test script for the new offload features
# This script demonstrates the resume, retry, and re-verify functionality

echo "=== Final Cut Git - Offload Feature Test ==="
echo ""

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test_offload"
SOURCE_DIR="$TEST_DIR/source"
DEST_DIR="$TEST_DIR/destination"

# Clean up any existing test files
rm -rf "$TEST_DIR"

# Create test directories
mkdir -p "$SOURCE_DIR"
mkdir -p "$DEST_DIR"

echo "Created test directories:"
echo "  Source: $SOURCE_DIR"
echo "  Destination: $DEST_DIR"
echo ""

# Create some test files
echo "Creating test files..."
for i in {1..5}; do
    echo "Test content for file $i" > "$SOURCE_DIR/test_file_$i.txt"
done

echo "Created 5 test files"
echo ""

# Set up the script environment
export SCRIPT_DIR="$SCRIPT_DIR/user"
export LOG_FILE="$TEST_DIR/test.log"
export DEBUG_MODE=true
export progressbar=true
export SILENT_MODE=false

# Source the compiled script
source "$SCRIPT_DIR/build/fcp-git-user.sh"

echo "=== Testing New Offload Features ==="
echo ""

# Test 1: Normal offload
echo "Test 1: Normal offload"
echo "Running offload with progress bar..."
run_offload_with_progress "$SOURCE_DIR" "test_source"
echo ""

# Test 2: Simulate incomplete offload
echo "Test 2: Simulate incomplete offload"
echo "Modifying .offload file to simulate incomplete status..."

# Create a modified .offload file with some files marked as queued
cat > "$SOURCE_DIR/.offload" << EOF
$SOURCE_DIR/test_file_1.txt|$DEST_DIR/v0001.PROJ.test_source.0001.txt|v0001.PROJ.test_source.0001.txt|verified
$SOURCE_DIR/test_file_2.txt|$DEST_DIR/v0001.PROJ.test_source.0002.txt|v0001.PROJ.test_source.0002.txt|queued
$SOURCE_DIR/test_file_3.txt|$DEST_DIR/v0001.PROJ.test_source.0003.txt|v0001.PROJ.test_source.0003.txt|failed
$SOURCE_DIR/test_file_4.txt|$DEST_DIR/v0001.PROJ.test_source.0004.txt|v0001.PROJ.test_source.0004.txt|queued
$SOURCE_DIR/test_file_5.txt|$DEST_DIR/v0001.PROJ.test_source.0005.txt|v0001.PROJ.test_source.0005.txt|verified
EOF

echo "Modified .offload file created with mixed statuses"
echo ""

# Test 3: Test status checking functions
echo "Test 3: Testing status checking functions"
echo "Checking offload status..."

# Test the status checking function
status=$(check_offload_status "$SOURCE_DIR/.offload")
stats=$(get_offload_stats "$SOURCE_DIR/.offload")

echo "Status: $status"
echo "Stats: $stats"
echo ""

# Test 4: Test the prompt function (without actual dialog)
echo "Test 4: Testing prompt function (simulated)"
echo "This would normally show a dialog to the user"
echo "For testing, we'll simulate the response"

# Simulate user choosing "Resume Offload"
echo "Simulating user choosing 'Resume Offload'..."
echo ""

# Test 5: Test resume functionality
echo "Test 5: Testing resume functionality"
echo "Running resume offload..."

# Call the resume function directly
resume_offload "$SOURCE_DIR" "$DEST_DIR" "PROJ" "test_source" "video" "1" "$SOURCE_DIR/.offload"
echo ""

# Test 6: Test retry functionality
echo "Test 6: Testing retry functionality"
echo "Modifying .offload file to simulate failed files..."

# Create a modified .offload file with failed files
cat > "$SOURCE_DIR/.offload" << EOF
$SOURCE_DIR/test_file_1.txt|$DEST_DIR/v0001.PROJ.test_source.0001.txt|v0001.PROJ.test_source.0001.txt|verified
$SOURCE_DIR/test_file_2.txt|$DEST_DIR/v0001.PROJ.test_source.0002.txt|v0001.PROJ.test_source.0002.txt|failed
$SOURCE_DIR/test_file_3.txt|$DEST_DIR/v0001.PROJ.test_source.0003.txt|v0001.PROJ.test_source.0003.txt|failed
$SOURCE_DIR/test_file_4.txt|$DEST_DIR/v0001.PROJ.test_source.0004.txt|v0001.PROJ.test_source.0004.txt|verified
$SOURCE_DIR/test_file_5.txt|$DEST_DIR/v0001.PROJ.test_source.0005.txt|v0001.PROJ.test_source.0005.txt|verified
EOF

echo "Running retry failed files..."
retry_failed_offload "$SOURCE_DIR" "$DEST_DIR" "PROJ" "test_source" "video" "1" "$SOURCE_DIR/.offload"
echo ""

# Test 7: Test re-verify functionality
echo "Test 7: Testing re-verify functionality"
echo "Modifying .offload file to simulate completed offload..."

# Create a modified .offload file with all files verified
cat > "$SOURCE_DIR/.offload" << EOF
$SOURCE_DIR/test_file_1.txt|$DEST_DIR/v0001.PROJ.test_source.0001.txt|v0001.PROJ.test_source.0001.txt|verified
$SOURCE_DIR/test_file_2.txt|$DEST_DIR/v0001.PROJ.test_source.0002.txt|v0001.PROJ.test_source.0002.txt|verified
$SOURCE_DIR/test_file_3.txt|$DEST_DIR/v0001.PROJ.test_source.0003.txt|v0001.PROJ.test_source.0003.txt|verified
$SOURCE_DIR/test_file_4.txt|$DEST_DIR/v0001.PROJ.test_source.0004.txt|v0001.PROJ.test_source.0004.txt|verified
$SOURCE_DIR/test_file_5.txt|$DEST_DIR/v0001.PROJ.test_source.0005.txt|v0001.PROJ.test_source.0005.txt|verified
EOF

echo "Running re-verify..."
reverify_offload "$SOURCE_DIR" "$DEST_DIR"
echo ""

echo "=== Test Complete ==="
echo "All offload features have been tested!"
echo "Check the log file at: $LOG_FILE"
echo ""
echo "Test files created:"
ls -la "$SOURCE_DIR"
echo ""
echo "Destination files:"
ls -la "$DEST_DIR" 