#!/bin/bash

#Cleanup Previous Install
echo -e "\n\nCleaning up existing containers, this may take a while!\n\n"
if command -v docker &> /dev/null; then
   containers=$(sudo docker ps -q)
   
   if [ -n "$containers" ]; then
     sudo docker stop $containers
   fi
   
   sudo docker system prune --all --force
   sudo docker volume prune --all --force

fi

#Update system
sudo apt-get update -y
sudo apt-get upgrade -y

#Install setup deps 
sudo apt-get install curl mokutil -y

# Check Secure Boot status
SECURE_BOOT_STATUS=$(mokutil --sb-state 2>/dev/null)

if echo "$SECURE_BOOT_STATUS" | grep -q "SecureBoot enabled"; then
    echo
    echo "Error: Secure Boot is enabled. Please disable it in BIOS/UEFI to proceed."
    echo
    exit 1
else
    echo "Secure Boot is disabled. Continuing..."
fi


#
#Install Docker
#

#Remove previous versions
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl -y
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo usermod -aG docker $USER

#
#Install Chrome
#
curl -fsSLO https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo dpkg -i ./google-chrome-stable_current_amd64.deb
sudo apt-get install -f -y

#
#Install Hailo Driver
#

#Deps to build and install kernel module
sudo apt-get install build-essential dkms pciutils -y 

# Run lspci -n and filter for vendor 1e60
devices=$(lspci -n | grep -i "1e60")

# Count device IDs
hailo8_count=$(echo "$devices" | grep -ci "1e60:2864")
hailo10_count=$(echo "$devices" | grep -ci "1e60:45c4")

# Initialize version variable
HAILO_VERSION=""

# Decision logic
if [[ $hailo8_count -gt 0 && $hailo10_count -gt 0 ]]; then
    HAILO_VERSION="Not_Supported"
    echo "Hailo-8 and Hailo-10 in the same system is not supported!"
elif [[ $hailo8_count -gt 0 ]]; then
    HAILO_VERSION="Hailo-8"
    echo "$HAILO_VERSION: $hailo8_count"
elif [[ $hailo10_count -gt 0 ]]; then
    HAILO_VERSION="Hailo-10"
    echo "$HAILO_VERSION: $hailo10_count"
else
    echo "No Supported Hailo devices found!"
fi

# Uninstall existing drivers

HAILO_PACKAGES=("hailo10h-driver-fw" "hailort-pcie-driver")

for pkg in "${HAILO_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg "; then
        echo "-I- Uninstalling $pkg"
        sudo apt-get remove --purge -y "$pkg"
    else
        echo "-I- $pkg not installed"
    fi
done

# Install appropriate driver
if [[ "$HAILO_VERSION" == "Hailo-8" ]]; then
    curl -fsSLO https://storage.googleapis.com/deepperception_public/hailo/h8/hailort-pcie-driver_4.21.0_all.deb 
    yes | sudo dpkg -i hailort-pcie-driver_4.21.0_all.deb
elif [[ "$HAILO_VERSION" == "Hailo-10" ]]; then
    curl -fsSLO https://storage.googleapis.com/deepperception_public/hailo/h10/hailort-pcie-driver_5.0.0_all.deb
    yes | sudo dpkg -i hailort-pcie-driver_5.0.0_all.deb 
else
    echo -e "\n\nSupported Hailo configuration not found, skipping driver install and exiting\n\n"
    exit 1
fi

### Detected NVIDIA Card

NV_DETECTED=false

# Method 1: Check if nvidia-smi command is available and working
if command -v nvidia-smi &> /dev/null; then
    if nvidia-smi &> /dev/null; then
        echo "NVIDIA GPU detected via nvidia-smi"
        NV_DETECTED=true
    fi
fi

# Method 2: Check lspci for NVIDIA devices (fallback)
if [[ "$NV_DETECTED" == "false" ]]; then
    if command -v lspci &> /dev/null; then
        if lspci | grep -i nvidia &> /dev/null; then
            echo "NVIDIA device detected via lspci"
            NV_DETECTED=true
        fi
    fi
fi

# Method 3: Check /proc/driver/nvidia (another fallback)
if [[ "$NV_DETECTED" == "false" ]]; then
    if [[ -d /proc/driver/nvidia ]]; then
        echo "NVIDIA driver detected in /proc/driver/nvidia"
        NV_DETECTED=true
    fi
fi

# Method 4: Check for NVIDIA kernel modules
if [[ "$NV_DETECTED" == "false" ]]; then
    if lsmod | grep -i nvidia &> /dev/null; then
        echo "NVIDIA kernel module detected"
        NV_DETECTED=true
    fi
fi

#Install NVIDIA Container Runtime if NV Detected
if [[ "$NV_DETECTED" == "true" ]]; then
    echo "Installing NVIDIA Container Toolkit..."

    # Add NVIDIA repository and GPG key (skip if already exists)
    if [[ ! -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg ]]; then
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    else
        echo "NVIDIA GPG key already exists, skipping download"
    fi

    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    sudo apt-get update

    export NVIDIA_CONTAINER_TOOLKIT_VERSION=1.17.8-1
    sudo apt-get install -y \
      nvidia-container-toolkit=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      nvidia-container-toolkit-base=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container-tools=${NVIDIA_CONTAINER_TOOLKIT_VERSION} \
      libnvidia-container1=${NVIDIA_CONTAINER_TOOLKIT_VERSION}
fi

# Copy the right docker-compose.yaml file
if [[ "$HAILO_VERSION" == "Hailo-8" ]]; then
    echo "HAILO_ARCH=h8" > ../.env
    echo "IMAGE_TAG=latest-h8" >> ../.env
    if [[ "$hailo8_count" -eq 1 ]]; then
        if [[ "$NV_DETECTED" == "true" ]]; then
            cp docker-compose.1hailo.nv.yaml ../docker-compose.yaml
        else
            cp docker-compose.1hailo.yaml ../docker-compose.yaml
        fi
    elif [[ "$hailo8_count" -eq 2 ]]; then
        if [[ "$NV_DETECTED" == "true" ]]; then
            cp docker-compose.2hailo.nv.yaml ../docker-compose.yaml
        else
            cp docker-compose.2hailo.yaml ../docker-compose.yaml
        fi
    elif [[ "$hailo8_count" -eq 4 ]]; then
        if [[ "$NV_DETECTED" == "true" ]]; then
            cp docker-compose.4hailo.nv.yaml ../docker-compose.yaml
        else
            cp docker-compose.4hailo.yaml ../docker-compose.yaml
        fi
    else
        echo -e "\n\nHailo-8: $hailo8_count devices not supported\n\n"
        exit 1
    fi
elif [[ "$HAILO_VERSION" == "Hailo-10" ]]; then
    echo "HAILO_ARCH=h10" > ../.env
    echo "IMAGE_TAG=latest" >> ../.env
    if [[ "$hailo10_count" -eq 1 ]]; then
        if [[ "$NV_DETECTED" == "true" ]]; then
            cp docker-compose.1hailo.nv.yaml ../docker-compose.yaml
        else
            cp docker-compose.1hailo.yaml ../docker-compose.yaml
        fi
    elif [[ "$hailo10_count" -eq 2 ]]; then
        if [[ "$NV_DETECTED" == "true" ]]; then
            cp docker-compose.2hailo.nv.yaml ../docker-compose.yaml
        else
            cp docker-compose.2hailo.yaml ../docker-compose.yaml
        fi
    elif [[ "$hailo10_count" -eq 4 ]]; then
        if [[ "$NV_DETECTED" == "true" ]]; then
            cp docker-compose.4hailo.nv.yaml ../docker-compose.yaml
        else
            cp docker-compose.4hailo.yaml ../docker-compose.yaml
        fi
    else
        echo -e "\n\nHailo-10: $hailo10_count devices not supported\n\n"
        exit 1
    fi
fi

#
#Install Misc Packages
#
sudo apt-get install openssh-server vim -y

sudo ./increase_fd_limits.sh

#
#Custom udev rule to work around onboard camera enumeration issue
#
sudo cp 99-custom-camera.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

# Remove downloaded debs
rm *.deb

echo -e "\n\nReboot Needed to Complete Hailo Driver Install!!!\n\n"
