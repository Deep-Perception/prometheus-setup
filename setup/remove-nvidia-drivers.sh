#!/bin/bash

# NVIDIA Package Removal Script for Ubuntu
# This script removes all NVIDIA drivers and related packages

echo "NVIDIA Package Removal Script"
echo "============================="
echo "This will remove ALL NVIDIA drivers and packages from your system."
echo "Make sure you have a backup plan for graphics drivers after removal."
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Please don't run this script as root. It will use sudo when needed."
   exit 1
fi

# Confirm with user
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 1
fi

echo "Starting NVIDIA package removal..."

# Stop display manager to prevent conflicts
echo "Stopping display manager..."
sudo systemctl stop gdm3 2>/dev/null || sudo systemctl stop lightdm 2>/dev/null || sudo systemctl stop sddm 2>/dev/null

# Remove NVIDIA packages
echo "Removing NVIDIA packages..."

# Remove proprietary NVIDIA drivers
sudo apt-get remove --purge -y nvidia-*
sudo apt-get remove --purge -y libnvidia-*

# Remove NVIDIA CUDA packages
sudo apt-get remove --purge -y cuda-*
sudo apt-get remove --purge -y libcuda*
sudo apt-get remove --purge -y nvidia-cuda-*

# Remove NVIDIA container toolkit
sudo apt-get remove --purge -y nvidia-container-*
sudo apt-get remove --purge -y nvidia-docker*

# Remove additional NVIDIA related packages
sudo apt-get remove --purge -y xserver-xorg-video-nvidia-*
sudo apt-get remove --purge -y nvidia-settings
sudo apt-get remove --purge -y nvidia-prime
sudo apt-get remove --purge -y nvidia-opencl-*

# Clean up broken packages and dependencies
echo "Cleaning up dependencies..."
sudo apt-get autoremove -y
sudo apt-get autoclean

# Remove NVIDIA configuration files
echo "Removing NVIDIA configuration files..."
sudo rm -rf /etc/nvidia-*
sudo rm -rf /usr/share/nvidia-*
sudo rm -f /etc/X11/xorg.conf
sudo rm -f /etc/X11/xorg.conf.backup

# Remove NVIDIA modprobe blacklist if exists
sudo rm -f /etc/modprobe.d/blacklist-nvidia.conf
sudo rm -f /etc/modprobe.d/nvidia-*

# Remove any remaining NVIDIA libraries
echo "Removing remaining NVIDIA libraries..."
sudo find /usr/lib -name "*nvidia*" -delete 2>/dev/null
sudo find /usr/lib32 -name "*nvidia*" -delete 2>/dev/null
sudo find /usr/lib/x86_64-linux-gnu -name "*nvidia*" -delete 2>/dev/null

# Update initramfs
echo "Updating initramfs..."
sudo update-initramfs -u

# Reconfigure X server to use default drivers
echo "Reconfiguring X server..."
sudo dpkg-reconfigure xserver-xorg

# Start display manager again
echo "Starting display manager..."
sudo systemctl start gdm3 2>/dev/null || sudo systemctl start lightdm 2>/dev/null || sudo systemctl start sddm 2>/dev/null

echo ""
echo "NVIDIA removal completed!"
echo "======================="
echo "What was done:"
echo "- Removed all NVIDIA proprietary drivers"
echo "- Removed CUDA packages"
echo "- Removed NVIDIA configuration files"
echo "- Cleaned up dependencies"
echo "- Updated initramfs"
echo "- Reconfigured X server"
echo ""
echo "IMPORTANT:"
echo "- Your system should now use open-source drivers (nouveau)"
echo "- You may need to reboot for all changes to take effect"
echo "- If you experience graphics issues, you may need to install mesa drivers:"
echo "  sudo apt-get install mesa-utils mesa-common-dev"
echo ""
read -p "Would you like to reboot now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting in 5 seconds..."
    sleep 5
    sudo reboot
else
    echo "Please reboot manually when convenient."
fi
