#!/bin/bash

# Test script to demonstrate the new filename generation functionality

# Source the offload script to get access to the function
source user/functions/offload.sh

# Test cases
echo "Testing filename generation with original names in parentheses:"
echo "=============================================================="

# Test 1: Audio file with normal naming
echo "Test 1 - Audio file (video mode):"
result=$(generate_filename_with_original "/path/to/audio/recording_001.wav" "v" "1" "PROJ" "source" "1" "video")
echo "Input: recording_001.wav"
echo "Output: $result"
echo ""

# Test 2: Audio file with audio mode
echo "Test 2 - Audio file (audio mode):"
result=$(generate_filename_with_original "/path/to/audio/recording_001.wav" "a" "1" "PROJ" "source" "1" "audio")
echo "Input: recording_001.wav"
echo "Output: $result"
echo ""

# Test 3: Video file with video mode
echo "Test 3 - Video file (video mode):"
result=$(generate_filename_with_original "/path/to/video/MAH00001.MP4" "v" "1" "PROJ" "source" "1" "video")
echo "Input: MAH00001.MP4"
echo "Output: $result"
echo ""

# Test 4: Photo file with photo mode
echo "Test 4 - Photo file (photo mode):"
result=$(generate_filename_with_original "/path/to/photo/IMG_1234.JPG" "p" "1" "PROJ" "source" "1" "photo")
echo "Input: IMG_1234.JPG"
echo "Output: $result"
echo ""

# Test 5: Maintain mode (should NOT include parentheses)
echo "Test 5 - Any file (maintain mode):"
result=$(generate_filename_with_original "/path/to/audio/recording_001.wav" "m" "1" "PROJ" "source" "1" "maintain")
echo "Input: recording_001.wav"
echo "Output: $result"
echo ""

# Test 6: File with special characters
echo "Test 6 - File with special characters:"
result=$(generate_filename_with_original "/path/to/audio/Recording (Take 1) - Scene 2.wav" "a" "1" "PROJ" "source" "1" "audio")
echo "Input: Recording (Take 1) - Scene 2.wav"
echo "Output: $result"
echo ""

# Test 7: File with very long name
echo "Test 7 - File with very long name:"
result=$(generate_filename_with_original "/path/to/audio/This_is_a_very_long_filename_that_should_be_truncated.wav" "a" "1" "PROJ" "source" "1" "audio")
echo "Input: This_is_a_very_long_filename_that_should_be_truncated.wav"
echo "Output: $result"
echo ""

echo "Testing complete!" 