#!/bin/bash

sudo apt-get update -y
sudo apt-get upgrade -y

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
curl -O -z google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb -y

#
#Install Hailo Driver
#
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
    HAILO_VERSION="not supported"
    echo "$HAILO_VERSION"
elif [[ $hailo8_count -gt 0 ]]; then
    HAILO_VERSION="Hailo-8"
    echo "$HAILO_VERSION: $hailo8_count"
elif [[ $hailo10_count -gt 0 ]]; then
    HAILO_VERSION="Hailo-10"
    echo "$HAILO_VERSION: $hailo10_count"
else
    echo "No Hailo devices found"
fi

# Install appropriate driver
if [[ "$HAILO_VERSION" == "Hailo-8" ]]; then
    curl -O -z hailort-pcie-driver_4.21.0_all.deb https://storage.googleapis.com/deepperception_public/hailo/h8/hailort-pcie-driver_4.21.0_all.deb 
    yes | sudo dpkg -i hailort-pcie-driver_4.21.0_all.deb
elif [[ "$HAILO_VERSION" == "Hailo-10" ]]; then
    curl -O -z 2280-hailo10h-driver-fw_4.22.0_all.deb https://storage.googleapis.com/deepperception_public/hailo/h10/2280-hailo10h-driver-fw_4.22.0_all.deb 
    yes | sudo dpkg -i 2280-hailo10h-driver-fw_4.22.0_all.deb
else
    echo "No supported Hailo device found, skipping driver install"
fi

# Copy the right docker-compose.yaml file

if [[ "$HAILO_VERSION" == "Hailo-8" ]]; then
    if [[ $hailo8_count -eq 1 ]]; then
	    echo "H8-1"
    elif [[ $hailo8_count -eq 2 ]]; then
	    echo "H8-2"
    elif [[ $hailo8_count -eq 4 ]]; then
            echo "H8-4"
    else
	    echo "Hailo-8:" $hailo8_count " not supported"
    fi
elif [[ "$HAILO_VERSION" == "Hailo-10" ]]; then
    if [[ $hailo10_count -eq 1 ]]; then
            echo "H10-1"
    elif [[ $hailo10_count -eq 2 ]]; then
            echo "H10-2"
    elif [[ $hailo10_count -eq 4 ]]; then
            echo "H10-4"
    else
            echo "Hailo-10:" $hailo10_count " not supported"
    fi
fi

#
#Install Misc Packages
#
sudo apt-get install nmap net-tools openssh-server vim -y

sudo ./increase_fd_limits.sh

#
#Custom udev rule to work around onboard camera enumeration issue
#
sudo cp 99-custom-camera.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

echo -e "\n\nReboot Needed to Complete Hailo Driver Install!!!\n\n"
