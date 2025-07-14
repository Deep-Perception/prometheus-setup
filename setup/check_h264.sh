#!/bin/bash

# Hardware H.264 Support Detection Script
# Checks for H.264 decode and encode capabilities using VAAPI (Intel/AMD) and NVDEC/NVENC (NVIDIA)
# This script should be run as root to access all hardware devices properly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
    esac
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install required packages
install_required_packages() {
    print_status "INFO" "Installing required packages..."
    
    # Detect package manager and install vainfo
    if command_exists apt-get; then
        print_status "INFO" "Using apt-get to install vainfo..."
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y vainfo >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_status "SUCCESS" "vainfo installed successfully"
        else
            print_status "ERROR" "Failed to install vainfo"
            return 1
        fi
    elif command_exists yum; then
        print_status "INFO" "Using yum to install libva-utils..."
        yum install -y libva-utils >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_status "SUCCESS" "libva-utils installed successfully"
        else
            print_status "ERROR" "Failed to install libva-utils"
            return 1
        fi
    elif command_exists dnf; then
        print_status "INFO" "Using dnf to install libva-utils..."
        dnf install -y libva-utils >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_status "SUCCESS" "libva-utils installed successfully"
        else
            print_status "ERROR" "Failed to install libva-utils"
            return 1
        fi
    elif command_exists pacman; then
        print_status "INFO" "Using pacman to install libva-utils..."
        pacman -S --noconfirm libva-utils >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_status "SUCCESS" "libva-utils installed successfully"
        else
            print_status "ERROR" "Failed to install libva-utils"
            return 1
        fi
    elif command_exists zypper; then
        print_status "INFO" "Using zypper to install libva-utils..."
        zypper install -y libva-utils >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            print_status "SUCCESS" "libva-utils installed successfully"
        else
            print_status "ERROR" "Failed to install libva-utils"
            return 1
        fi
    else
        print_status "ERROR" "No supported package manager found"
        print_status "INFO" "Please install vainfo manually:"
        print_status "INFO" "  - Ubuntu/Debian: apt-get install vainfo"
        print_status "INFO" "  - RHEL/CentOS: yum install libva-utils"
        print_status "INFO" "  - Fedora: dnf install libva-utils"
        print_status "INFO" "  - Arch: pacman -S libva-utils"
        print_status "INFO" "  - OpenSUSE: zypper install libva-utils"
        return 1
    fi
    
    return 0
}

# Function to check for NVIDIA GPU and drivers
check_nvidia_gpu() {
    print_status "INFO" "Checking for NVIDIA GPU and drivers..."
    
    local nvidia_present=0
    
    # Check for NVIDIA GPU
    if command_exists lspci; then
        if lspci | grep -i nvidia | grep -i vga >/dev/null 2>&1; then
            print_status "SUCCESS" "NVIDIA GPU detected:"
            lspci | grep -i nvidia | grep -i vga | head -3
            nvidia_present=1
        fi
    fi
    
    # Check for NVIDIA drivers
    if command_exists nvidia-smi; then
        print_status "SUCCESS" "NVIDIA drivers detected"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader,nounits | head -1
        nvidia_present=1
    elif [ -f /proc/driver/nvidia/version ]; then
        print_status "SUCCESS" "NVIDIA drivers detected"
        cat /proc/driver/nvidia/version | head -1
        nvidia_present=1
    fi
    
    # Check for loaded nvidia modules
    if command_exists lsmod; then
        if lsmod | grep -q nvidia; then
            print_status "SUCCESS" "NVIDIA kernel modules loaded"
            nvidia_present=1
        fi
    fi
    
    if [ $nvidia_present -eq 0 ]; then
        print_status "INFO" "No NVIDIA GPU or drivers detected"
        return 1
    fi
    
    return 0
}

# Function to check NVDEC support
check_nvdec_support() {
    print_status "INFO" "Checking NVDEC (NVIDIA decode) support..."
    
    local nvdec_supported=0
    
    # Method 1: Check for NVDEC library
    if ls /usr/lib/x86_64-linux-gnu/libnvcuvid.so* >/dev/null 2>&1 || \
       ls /usr/lib64/libnvcuvid.so* >/dev/null 2>&1 || \
       ls /usr/local/cuda/lib64/libnvcuvid.so* >/dev/null 2>&1; then
        print_status "SUCCESS" "NVDEC library (libnvcuvid) found"
        nvdec_supported=1
    fi
    
    # Method 2: Try nvidia-smi decoder query (newer drivers)
    if command_exists nvidia-smi; then
        local decoder_info
        decoder_info=$(nvidia-smi --query-gpu=decoder.util --format=csv,noheader,nounits 2>/dev/null)
        
        if [ -n "$decoder_info" ] && [ "$decoder_info" != "[Not Supported]" ]; then
            print_status "SUCCESS" "NVDEC supported (nvidia-smi query successful)"
            nvdec_supported=1
        fi
        
        # Method 3: Check GPU generation (fallback)
        local gpu_name
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
        
        if [ -n "$gpu_name" ]; then
            # NVDEC is supported on Maxwell (GTX 9xx) and newer
            case "$gpu_name" in
                *"GTX 9"*|*"GTX 10"*|*"GTX 16"*|*"RTX"*|*"Tesla"*|*"Quadro"*|*"A100"*|*"A40"*|*"A30"*|*"A10"*|*"T4"*)
                    print_status "SUCCESS" "NVDEC supported (GPU: $gpu_name)"
                    nvdec_supported=1
                    ;;
                *)
                    # Check if it's a newer architecture we might not know about
                    local compute_cap
                    compute_cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits | head -1 2>/dev/null)
                    if [ -n "$compute_cap" ] && [ "$(echo "$compute_cap" | cut -d. -f1)" -ge 5 ]; then
                        print_status "SUCCESS" "NVDEC likely supported (compute capability $compute_cap >= 5.0)"
                        nvdec_supported=1
                    fi
                    ;;
            esac
        fi
    fi
    
    # Method 4: Check with ffmpeg if available
    if [ $nvdec_supported -eq 0 ] && command_exists ffmpeg; then
        if ffmpeg -decoders 2>/dev/null | grep -q "h264_cuvid"; then
            print_status "SUCCESS" "NVDEC supported (FFmpeg h264_cuvid decoder available)"
            nvdec_supported=1
        fi
    fi
    
    if [ $nvdec_supported -eq 1 ]; then
        return 0
    else
        print_status "ERROR" "NVDEC not supported or not properly installed"
        return 1
    fi
}

# Function to check NVENC support
check_nvenc_support() {
    print_status "INFO" "Checking NVENC (NVIDIA encode) support..."
    
    local nvenc_supported=0
    
    # Method 1: Check for NVENC library
    if ls /usr/lib/x86_64-linux-gnu/libnvidia-encode.so* >/dev/null 2>&1 || \
       ls /usr/lib64/libnvidia-encode.so* >/dev/null 2>&1 || \
       ls /usr/local/cuda/lib64/libnvidia-encode.so* >/dev/null 2>&1; then
        print_status "SUCCESS" "NVENC library (libnvidia-encode) found"
        nvenc_supported=1
    fi
    
    # Method 2: Try nvidia-smi encoder query (newer drivers)
    if command_exists nvidia-smi; then
        local encoder_info
        encoder_info=$(nvidia-smi --query-gpu=encoder.stats.sessionCount --format=csv,noheader,nounits 2>/dev/null)
        
        if [ -n "$encoder_info" ] && [ "$encoder_info" != "[Not Supported]" ]; then
            print_status "SUCCESS" "NVENC supported (nvidia-smi query successful)"
            nvenc_supported=1
        fi
        
        # Method 3: Check GPU generation (fallback)
        local gpu_name
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits | head -1)
        
        if [ -n "$gpu_name" ]; then
            # NVENC is supported on Kepler (GTX 6xx/7xx) and newer
            case "$gpu_name" in
                *"GTX 6"*|*"GTX 7"*|*"GTX 9"*|*"GTX 10"*|*"GTX 16"*|*"RTX"*|*"Tesla"*|*"Quadro"*|*"A100"*|*"A40"*|*"A30"*|*"A10"*|*"T4"*)
                    print_status "SUCCESS" "NVENC supported (GPU: $gpu_name)"
                    nvenc_supported=1
                    ;;
                *)
                    # Check if it's a newer architecture we might not know about
                    local compute_cap
                    compute_cap=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits | head -1 2>/dev/null)
                    if [ -n "$compute_cap" ] && [ "$(echo "$compute_cap" | cut -d. -f1)" -ge 3 ]; then
                        print_status "SUCCESS" "NVENC likely supported (compute capability $compute_cap >= 3.0)"
                        nvenc_supported=1
                    fi
                    ;;
            esac
        fi
    fi
    
    # Method 4: Check with ffmpeg if available
    if [ $nvenc_supported -eq 0 ] && command_exists ffmpeg; then
        if ffmpeg -encoders 2>/dev/null | grep -q "h264_nvenc"; then
            print_status "SUCCESS" "NVENC supported (FFmpeg h264_nvenc encoder available)"
            nvenc_supported=1
        fi
    fi
    
    # Method 5: Check session limit (indicates NVENC presence)
    if [ $nvenc_supported -eq 0 ] && command_exists nvidia-smi; then
        if nvidia-smi -h 2>&1 | grep -q "encoder.stats"; then
            print_status "INFO" "NVENC encoder stats available in nvidia-smi"
            nvenc_supported=1
        fi
    fi
    
    if [ $nvenc_supported -eq 1 ]; then
        return 0
    else
        print_status "ERROR" "NVENC not supported or not properly installed"
        return 1
    fi
}

# Function to check VAAPI device
check_vaapi_device() {
    print_status "INFO" "Checking for VAAPI devices..."
    
    # First identify which devices belong to which GPU
    if ! identify_gpu_devices; then
        return 1
    fi
    
    return 0
}

# Function to get NVIDIA encoder capabilities
check_nvidia_capabilities() {
    print_status "INFO" "Checking NVIDIA GPU capabilities..."
    
    if ! command_exists nvidia-smi; then
        print_status "WARNING" "nvidia-smi not available, cannot check GPU capabilities"
        return 1
    fi
    
    # Get GPU information
    local gpu_info
    gpu_info=$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader,nounits)
    
    if [ -n "$gpu_info" ]; then
        print_status "INFO" "GPU Information:"
        echo "$gpu_info" | while IFS=, read -r name driver_version memory; do
            echo "  Name: $name"
            echo "  Driver Version: $driver_version"
            echo "  Memory: ${memory} MB"
        done
        echo
        
        # Try to query encoder/decoder capabilities (newer drivers)
        print_status "INFO" "Checking video codec capabilities..."
        
        # List NVENC/NVDEC libraries if present
        print_status "INFO" "Checking for Video Codec SDK libraries..."
        local libs_found=0
        
        for lib_path in /usr/lib/x86_64-linux-gnu /usr/lib64 /usr/local/cuda/lib64; do
            if [ -d "$lib_path" ]; then
                if ls "$lib_path"/libnvidia-encode.so* >/dev/null 2>&1; then
                    print_status "SUCCESS" "  NVENC library found in $lib_path"
                    libs_found=1
                fi
                if ls "$lib_path"/libnvcuvid.so* >/dev/null 2>&1; then
                    print_status "SUCCESS" "  NVDEC library found in $lib_path"
                    libs_found=1
                fi
            fi
        done
        
        if [ $libs_found -eq 0 ]; then
            print_status "WARNING" "  No Video Codec SDK libraries found"
            print_status "INFO" "  This may indicate incomplete driver installation"
        fi
    fi
    
    return 0
}

# Function to identify GPU type for each DRM device
identify_gpu_devices() {
    print_status "INFO" "Identifying GPU devices..."
    
    local intel_devices=()
    local amd_devices=()
    local nvidia_devices=()
    
    if ls /dev/dri/renderD* >/dev/null 2>&1; then
        for device in /dev/dri/renderD*; do
            if [ -c "$device" ]; then
                local device_identified=0
                
                # Method 1: Try udev info
                local device_info
                if device_info=$(udevadm info --name="$device" 2>/dev/null); then
                    if echo "$device_info" | grep -qi "intel"; then
                        intel_devices+=("$device")
                        print_status "INFO" "Intel GPU device: $device (udev)"
                        device_identified=1
                    elif echo "$device_info" | grep -qi "amd\|radeon"; then
                        amd_devices+=("$device")
                        print_status "INFO" "AMD GPU device: $device (udev)"
                        device_identified=1
                    elif echo "$device_info" | grep -qi "nvidia"; then
                        nvidia_devices+=("$device")
                        print_status "INFO" "NVIDIA GPU device: $device (udev - skipping for VAAPI)"
                        device_identified=1
                    fi
                fi
                
                # Method 2: Try PCI path lookup
                if [ $device_identified -eq 0 ] && [ -n "$device_info" ]; then
                    local pci_path
                    pci_path=$(echo "$device_info" | grep "ID_PATH=" | cut -d'=' -f2)
                    if [ -n "$pci_path" ]; then
                        local pci_device
                        pci_device=$(echo "$pci_path" | grep -o 'pci-[^-]*' | cut -d'-' -f2)
                        if [ -n "$pci_device" ]; then
                            local gpu_info
                            gpu_info=$(lspci -s "$pci_device" 2>/dev/null)
                            if echo "$gpu_info" | grep -qi "intel"; then
                                intel_devices+=("$device")
                                print_status "INFO" "Intel GPU device: $device (PCI: $gpu_info)"
                                device_identified=1
                            elif echo "$gpu_info" | grep -qi "amd\|radeon"; then
                                amd_devices+=("$device")
                                print_status "INFO" "AMD GPU device: $device (PCI: $gpu_info)"
                                device_identified=1
                            elif echo "$gpu_info" | grep -qi "nvidia"; then
                                nvidia_devices+=("$device")
                                print_status "INFO" "NVIDIA GPU device: $device (PCI: $gpu_info - skipping for VAAPI)"
                                device_identified=1
                            fi
                        fi
                    fi
                fi
                
                # Method 3: Try driver name from device info
                if [ $device_identified -eq 0 ] && [ -n "$device_info" ]; then
                    local driver_name
                    driver_name=$(echo "$device_info" | grep "DRIVER=" | cut -d'=' -f2)
                    if [ -n "$driver_name" ]; then
                        case "$driver_name" in
                            "i915"|"xe")
                                intel_devices+=("$device")
                                print_status "INFO" "Intel GPU device: $device (driver: $driver_name)"
                                device_identified=1
                                ;;
                            "amdgpu"|"radeon")
                                amd_devices+=("$device")
                                print_status "INFO" "AMD GPU device: $device (driver: $driver_name)"
                                device_identified=1
                                ;;
                            "nvidia"|"nvidia-drm")
                                nvidia_devices+=("$device")
                                print_status "INFO" "NVIDIA GPU device: $device (driver: $driver_name - skipping for VAAPI)"
                                device_identified=1
                                ;;
                        esac
                    fi
                fi
                
                # Method 4: Try direct vainfo test as last resort
                if [ $device_identified -eq 0 ]; then
                    if command_exists vainfo; then
                        local vainfo_test
                        if vainfo_test=$(vainfo --display drm --device "$device" 2>&1); then
                            if echo "$vainfo_test" | grep -q "VAProfile"; then
                                # If vainfo works, it's likely Intel or AMD
                                if echo "$vainfo_test" | grep -qi "intel"; then
                                    intel_devices+=("$device")
                                    print_status "INFO" "Intel GPU device: $device (vainfo test)"
                                    device_identified=1
                                elif echo "$vainfo_test" | grep -qi "amd\|radeon"; then
                                    amd_devices+=("$device")
                                    print_status "INFO" "AMD GPU device: $device (vainfo test)"
                                    device_identified=1
                                else
                                    # Generic VAAPI device
                                    intel_devices+=("$device")
                                    print_status "INFO" "VAAPI-capable device: $device (assuming Intel/AMD)"
                                    device_identified=1
                                fi
                            fi
                        fi
                    fi
                fi
                
                # If still unknown, show debug info
                if [ $device_identified -eq 0 ]; then
                    print_status "INFO" "Unknown GPU device: $device"
                    print_status "INFO" "  Device info preview:"
                    echo "$device_info" | grep -E "(DRIVER|ID_VENDOR|ID_MODEL|ID_PATH)" | head -3 | sed 's/^/    /'
                fi
            fi
        done
    fi
    
    # Export arrays for use in other functions
    export INTEL_DEVICES="${intel_devices[*]}"
    export AMD_DEVICES="${amd_devices[*]}"
    export NVIDIA_DEVICES="${nvidia_devices[*]}"
    
    print_status "INFO" "Device summary:"
    print_status "INFO" "  Intel/xe devices: ${#intel_devices[@]}"
    print_status "INFO" "  AMD devices: ${#amd_devices[@]}"
    print_status "INFO" "  NVIDIA devices: ${#nvidia_devices[@]}"
    
    if [ ${#intel_devices[@]} -eq 0 ] && [ ${#amd_devices[@]} -eq 0 ]; then
        print_status "INFO" "No Intel or AMD GPU devices found for VAAPI testing"
        return 1
    fi
    
    return 0
}

# Function to check vainfo
check_vainfo() {
    print_status "INFO" "Checking vainfo output..."
    
    # Check if vainfo is available, install if needed
    if ! command_exists vainfo; then
        print_status "WARNING" "vainfo not found. Attempting to install..."
        
        if install_required_packages; then
            print_status "SUCCESS" "vainfo installed, continuing with detection..."
        else
            print_status "ERROR" "Failed to install vainfo. Please install manually."
            return 1
        fi
        
        # Check again after installation
        if ! command_exists vainfo; then
            print_status "ERROR" "vainfo still not available after installation attempt"
            return 1
        fi
    fi
    
    # Get the device arrays
    intel_devices=($INTEL_DEVICES)
    amd_devices=($AMD_DEVICES)
    vaapi_devices=("${intel_devices[@]}" "${amd_devices[@]}")
    
    if [ ${#vaapi_devices[@]} -eq 0 ]; then
        print_status "ERROR" "No Intel or AMD devices found for VAAPI testing"
        return 1
    fi
    
    # Test each VAAPI-capable device
    success=0
    for device in "${vaapi_devices[@]}"; do
        print_status "INFO" "Testing VAAPI device: $device"
        
        # Try multiple methods to query the device
        vainfo_output=""
        
        # Method 1: Basic vainfo with device specification
        if vainfo_output=$(vainfo --display drm --device "$device" 2>&1); then
            if echo "$vainfo_output" | grep -q "VAProfile"; then
                print_status "SUCCESS" "VAAPI working on $device"
                echo "$vainfo_output" | grep -E "(VAProfile|VAEntrypoint)" | head -20
                success=1
                export VAAPI_DEVICE="$device"
                break
            fi
        fi
        
        # Method 2: Try with DRM_DEVICE environment variable
        if [ $success -eq 0 ]; then
            if vainfo_output=$(DRM_DEVICE="$device" vainfo 2>&1); then
                if echo "$vainfo_output" | grep -q "VAProfile"; then
                    print_status "SUCCESS" "VAAPI working on $device (via DRM_DEVICE)"
                    echo "$vainfo_output" | grep -E "(VAProfile|VAEntrypoint)" | head -20
                    success=1
                    export VAAPI_DEVICE="$device"
                    break
                fi
            fi
        fi
        
        # Show error details for debugging
        if [ $success -eq 0 ]; then
            print_status "WARNING" "Failed to query $device"
            echo "$vainfo_output" | head -3 | sed 's/^/    /'
        fi
    done
    
    # Try default vainfo as fallback
    if [ $success -eq 0 ]; then
        print_status "INFO" "Trying default vainfo..."
        if vainfo_output=$(vainfo 2>&1); then
            if echo "$vainfo_output" | grep -q "VAProfile"; then
                print_status "SUCCESS" "VAAPI working with default device"
                echo "$vainfo_output" | grep -E "(VAProfile|VAEntrypoint)" | head -20
                success=1
                export VAAPI_DEVICE=""
            fi
        fi
    fi
    
    if [ $success -eq 0 ]; then
        print_status "ERROR" "No working VAAPI device found"
        print_status "INFO" "This could be due to:"
        print_status "INFO" "  - Missing VAAPI drivers (intel-media-va-driver, mesa-va-drivers)"
        print_status "INFO" "  - Incorrect permissions on /dev/dri/ devices"
        print_status "INFO" "  - GPU not supporting VAAPI"
        
        # Show installed drivers
        print_status "INFO" "Checking for installed VAAPI drivers:"
        if ls /usr/lib/x86_64-linux-gnu/dri/*_drv_video.so 2>/dev/null | head -5; then
            print_status "INFO" "Found VAAPI drivers:"
            ls /usr/lib/x86_64-linux-gnu/dri/*_drv_video.so 2>/dev/null | sed 's/^/    /'
        else
            print_status "WARNING" "No VAAPI drivers found in /usr/lib/x86_64-linux-gnu/dri/"
        fi
        
        return 1
    fi
    
    return 0
}

# Function to check H.264 decode support
check_h264_decode() {
    print_status "INFO" "Checking H.264 decode support..."
    
    # Check if vainfo is available (should be installed by now)
    if ! command_exists vainfo; then
        print_status "ERROR" "vainfo not available"
        return 1
    fi
    
    # Use the device that was found to work in check_vainfo
    local vainfo_cmd="vainfo"
    if [ -n "$VAAPI_DEVICE" ]; then
        vainfo_cmd="vainfo --display drm --device $VAAPI_DEVICE"
    fi
    
    local vainfo_output
    vainfo_output=$($vainfo_cmd 2>/dev/null)
    
    # Check for H.264 decode profiles
    if echo "$vainfo_output" | grep -q "VAProfileH264.*VAEntrypointVLD"; then
        print_status "SUCCESS" "H.264 decode supported"
        
        # Show supported H.264 decode profiles
        echo "$vainfo_output" | grep "VAProfileH264.*VAEntrypointVLD" | while read -r line; do
            print_status "INFO" "  $line"
        done
        return 0
    else
        print_status "ERROR" "H.264 decode not supported"
        return 1
    fi
}

# Function to check H.264 encode support
check_h264_encode() {
    print_status "INFO" "Checking H.264 encode support..."
    
    # Check if vainfo is available (should be installed by now)
    if ! command_exists vainfo; then
        print_status "ERROR" "vainfo not available"
        return 1
    fi
    
    # Use the device that was found to work in check_vainfo
    local vainfo_cmd="vainfo"
    if [ -n "$VAAPI_DEVICE" ]; then
        vainfo_cmd="vainfo --display drm --device $VAAPI_DEVICE"
    fi
    
    local vainfo_output
    vainfo_output=$($vainfo_cmd 2>/dev/null)
    
    # Check for H.264 encode profiles
    if echo "$vainfo_output" | grep -q "VAProfileH264.*VAEntrypointEncSlice"; then
        print_status "SUCCESS" "H.264 encode supported"
        
        # Show supported H.264 encode profiles
        echo "$vainfo_output" | grep "VAProfileH264.*VAEntrypointEncSlice" | while read -r line; do
            print_status "INFO" "  $line"
        done
        return 0
    else
        print_status "ERROR" "H.264 encode not supported"
        return 1
    fi
}

# Function to show system information
show_system_info() {
    print_status "INFO" "System Information:"
    print_status "INFO" "Running as: $(whoami) (UID: $EUID)"
    
    # GPU information
    if command_exists lspci; then
        echo "GPU(s):"
        lspci | grep -i vga | head -5
        echo
    fi
    
    # Driver information
    if command_exists lsmod; then
        echo "Graphics drivers loaded:"
        lsmod | grep -E "(i915|amdgpu|radeon|nouveau|nvidia)" | head -10
        echo
    fi
    
    # Mesa version
    if command_exists glxinfo; then
        echo "Mesa version:"
        glxinfo | grep "OpenGL version" | head -1
        echo
    fi
    
    # DRM device permissions
    echo "DRM device permissions:"
    ls -la /dev/dri/ | head -10
    echo
}

# Main function
main() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        print_status "ERROR" "This script must be run as root"
        print_status "INFO" "Please run: sudo $0"
        exit 1
    fi

    echo "======================================"
    echo "Hardware H.264 Support Detection Script"
    echo "======================================"
    echo
    
    local vaapi_decode_supported=0
    local vaapi_encode_supported=0
    local nvdec_supported=0
    local nvenc_supported=0
    local nvidia_gpu_present=0
    local vaapi_device_present=0
    
    # Show system info
    show_system_info
    
    # Check for NVIDIA GPU and drivers
    if check_nvidia_gpu; then
        nvidia_gpu_present=1
        echo
        check_nvidia_capabilities
        echo
    fi
    
    # Check VAAPI device
    if check_vaapi_device; then
        vaapi_device_present=1
        echo
        
        # Check vainfo output
        check_vainfo
        echo
        
        # Check VAAPI H.264 decode
        if check_h264_decode; then
            vaapi_decode_supported=1
        fi
        echo
        
        # Check VAAPI H.264 encode
        if check_h264_encode; then
            vaapi_encode_supported=1
        fi
        echo
    fi
    
    # Check NVIDIA capabilities if GPU is present
    if [ $nvidia_gpu_present -eq 1 ]; then
        # Check NVDEC
        if check_nvdec_support; then
            nvdec_supported=1
        fi
        echo
        
        # Check NVENC
        if check_nvenc_support; then
            nvenc_supported=1
        fi
        echo
    fi
    
    # Summary
    echo "======================================"
    echo "SUMMARY"
    echo "======================================"
    
    # VAAPI Results
    echo "VAAPI (Intel/AMD):"
    if [ $vaapi_device_present -eq 1 ]; then
        if [ $vaapi_decode_supported -eq 1 ]; then
            print_status "SUCCESS" "  H.264 decode: SUPPORTED"
        else
            print_status "ERROR" "  H.264 decode: NOT SUPPORTED"
        fi
        
        if [ $vaapi_encode_supported -eq 1 ]; then
            print_status "SUCCESS" "  H.264 encode: SUPPORTED"
        else
            print_status "ERROR" "  H.264 encode: NOT SUPPORTED"
        fi
    else
        print_status "INFO" "  VAAPI device not available"
    fi
    
    echo
    
    # NVIDIA Results
    echo "NVIDIA NVDEC/NVENC:"
    if [ $nvidia_gpu_present -eq 1 ]; then
        if [ $nvdec_supported -eq 1 ]; then
            print_status "SUCCESS" "  H.264 decode (NVDEC): SUPPORTED"
        else
            print_status "ERROR" "  H.264 decode (NVDEC): NOT SUPPORTED"
        fi
        
        if [ $nvenc_supported -eq 1 ]; then
            print_status "SUCCESS" "  H.264 encode (NVENC): SUPPORTED"
        else
            print_status "ERROR" "  H.264 encode (NVENC): NOT SUPPORTED"
        fi
    else
        print_status "INFO" "  NVIDIA GPU not available"
    fi
    
    echo
    
    # Overall results
    local total_decode_support=$((vaapi_decode_supported + nvdec_supported))
    local total_encode_support=$((vaapi_encode_supported + nvenc_supported))
    
    if [ $total_decode_support -gt 0 ] && [ $total_encode_support -gt 0 ]; then
        print_status "SUCCESS" "Hardware H.264 decode and encode support detected!"
        exit 0
    elif [ $total_decode_support -gt 0 ] || [ $total_encode_support -gt 0 ]; then
        print_status "WARNING" "Partial hardware H.264 support detected"
        exit 1
    else
        print_status "ERROR" "No hardware H.264 support detected"
        exit 2
    fi
}

# Run main function
main "$@"
