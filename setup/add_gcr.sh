#!/bin/bash

#
#Install gcloud SDK
#

if ! command -v gcloud &> /dev/null; then
    echo "Google Cloud CLI is not installed. Proceeding with installation..."

    # Install prerequisites
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates gnupg

    # Add Google Cloud's public GPG key
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

    # Remove any existing Google Cloud SDK list
    sudo rm -f /etc/apt/sources.list.d/google-cloud-sdk.list

    # Add Google Cloud SDK repository
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list

    # Update package list
    sudo apt update

    # Install Google Cloud CLI
    sudo apt install -y google-cloud-cli

    echo "Google Cloud CLI installation completed."
else
    echo "Google Cloud CLI is already installed. Skipping installation."
fi

#
#Add Private Registry
#

gcloud auth activate-service-account --key-file=service_account.json
gcloud auth configure-docker us-central1-docker.pkg.dev

#docker run us-central1-docker.pkg.dev/deepperception-challenger/demo1/hello-world:latest
