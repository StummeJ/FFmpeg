#!/bin/bash
# FFmpeg CUDA Build Validation Script
# Tests a built FFmpeg executable for core functionality and CUDA support

set -e

FFMPEG_PATH="${1:-./ffmpeg.exe}"
TEST_DIR="${2:-./ffmpeg-test}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'  
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

test_result() {
    local test_name="$1"
    local result="$2"
    
    if [ "$result" -eq 0 ]; then
        log_info "✓ $test_name"
        ((TESTS_PASSED++))
    else
        log_error "✗ $test_name"
        ((TESTS_FAILED++))
    fi
}

test_skip() {
    local test_name="$1"
    local reason="$2"
    log_warn "⊘ $test_name (skipped: $reason)"
    ((TESTS_SKIPPED++))
}

# Validate executable exists
if [ ! -f "$FFMPEG_PATH" ]; then
    log_error "FFmpeg executable not found at: $FFMPEG_PATH"
    exit 1
fi

log_info "Starting FFmpeg validation tests..."
log_info "Executable: $FFMPEG_PATH"

# Create test directory
mkdir -p "$TEST_DIR"

# Test 1: Basic version check
log_info "Testing basic functionality..."
"$FFMPEG_PATH" -version > "$TEST_DIR/version.log" 2>&1
test_result "Version check" $?

# Test 2: Codec listing  
"$FFMPEG_PATH" -codecs > "$TEST_DIR/codecs.log" 2>&1
test_result "Codec enumeration" $?

# Test 3: Hardware accelerator listing
"$FFMPEG_PATH" -hwaccels > "$TEST_DIR/hwaccels.log" 2>&1
test_result "Hardware accelerator enumeration" $?

# Test 4: Check for CUDA support
log_info "Checking CUDA support..."
if "$FFMPEG_PATH" -encoders 2>/dev/null | grep -q "nvenc"; then
    test_result "NVENC encoder availability" 0
    
    # List all NVENC encoders
    log_info "Available NVENC encoders:"
    "$FFMPEG_PATH" -encoders 2>/dev/null | grep "nvenc" | while read line; do
        echo "  - $line"
    done > "$TEST_DIR/nvenc-encoders.log"
else
    test_result "NVENC encoder availability" 1
fi

if "$FFMPEG_PATH" -decoders 2>/dev/null | grep -q "cuvid"; then
    test_result "CUVID decoder availability" 0
else  
    test_result "CUVID decoder availability" 1
fi

# Test 5: Check for key video codecs
log_info "Checking video codec support..."
codecs_to_check=("h264" "hevc" "av1" "vp9" "libx264" "libx265")
for codec in "${codecs_to_check[@]}"; do
    if "$FFMPEG_PATH" -codecs 2>/dev/null | grep -q "$codec"; then
        test_result "$codec codec support" 0
    else
        test_result "$codec codec support" 1
    fi
done

# Test 6: Check for key audio codecs
log_info "Checking audio codec support..."
audio_codecs=("opus" "vorbis" "mp3" "aac")
for codec in "${audio_codecs[@]}"; do
    if "$FFMPEG_PATH" -codecs 2>/dev/null | grep -q "$codec"; then
        test_result "$codec audio codec support" 0
    else
        test_result "$codec audio codec support" 1
    fi
done

# Test 7: Check for important filters
log_info "Checking filter support..."
filters_to_check=("scale" "libplacebo" "scale_cuda")
for filter in "${filters_to_check[@]}"; do
    if "$FFMPEG_PATH" -filters 2>/dev/null | grep -q "$filter"; then
        test_result "$filter filter support" 0
    else
        test_result "$filter filter support" 1
    fi
done

# Test 8: Basic transcoding test (if test media exists)
log_info "Testing basic transcoding..."
if command -v ffmpeg >/dev/null 2>&1; then
    # Generate test video if system ffmpeg is available
    if ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=1 -pix_fmt yuv420p "$TEST_DIR/test_input.mp4" -y 2>/dev/null; then
        # Test basic transcoding
        if "$FFMPEG_PATH" -i "$TEST_DIR/test_input.mp4" -c:v libx264 -crf 30 -t 1 "$TEST_DIR/test_output.mp4" -y >/dev/null 2>&1; then
            test_result "Basic H.264 encoding" 0
        else
            test_result "Basic H.264 encoding" 1
        fi
        
        # Test NVENC if available (might fail on systems without NVIDIA GPU)
        if "$FFMPEG_PATH" -encoders 2>/dev/null | grep -q "h264_nvenc"; then
            if "$FFMPEG_PATH" -i "$TEST_DIR/test_input.mp4" -c:v h264_nvenc -preset fast -t 1 "$TEST_DIR/test_nvenc.mp4" -y >/dev/null 2>&1; then
                test_result "NVENC H.264 encoding" 0
            else
                test_skip "NVENC H.264 encoding" "no compatible GPU or driver"
            fi
        else
            test_skip "NVENC H.264 encoding" "encoder not available"
        fi
    else
        test_skip "Transcoding tests" "failed to generate test media"
    fi
else
    test_skip "Transcoding tests" "no system ffmpeg to generate test media"
fi

# Test 9: Check DLL dependencies (Windows specific)
if command -v ldd >/dev/null 2>&1 || command -v objdump >/dev/null 2>&1; then
    log_info "Checking DLL dependencies..."
    if ldd "$FFMPEG_PATH" > "$TEST_DIR/dependencies.log" 2>&1 || objdump -p "$FFMPEG_PATH" | grep "DLL Name" > "$TEST_DIR/dependencies.log" 2>&1; then
        # Check for expected CUDA libraries
        if grep -q -i "cuda\|npp\|nvenc" "$TEST_DIR/dependencies.log"; then
            test_result "CUDA library linkage" 0
        else
            test_result "CUDA library linkage" 1
        fi
        test_result "Dependency analysis" 0
    else
        test_result "Dependency analysis" 1
    fi
else
    test_skip "Dependency analysis" "ldd/objdump not available"
fi

# Cleanup generated test files
if [ -f "$TEST_DIR/test_input.mp4" ]; then
    rm -f "$TEST_DIR/test_input.mp4" "$TEST_DIR/test_output.mp4" "$TEST_DIR/test_nvenc.mp4"
fi

# Final summary
log_info "=== Validation Summary ==="
log_info "Tests passed: $TESTS_PASSED"
if [ $TESTS_FAILED -gt 0 ]; then
    log_error "Tests failed: $TESTS_FAILED"
fi
if [ $TESTS_SKIPPED -gt 0 ]; then
    log_warn "Tests skipped: $TESTS_SKIPPED"
fi

total_tests=$((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))
log_info "Total tests: $total_tests"

if [ $TESTS_FAILED -eq 0 ]; then
    log_info "All tests passed! FFmpeg build appears to be working correctly."
    exit 0
else
    log_error "Some tests failed. Check the logs in $TEST_DIR/ for details."
    exit 1
fi