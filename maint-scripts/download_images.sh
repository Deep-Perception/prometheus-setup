#!/bin/bash

# Set the output directory for the tar files
OUTPUT_DIR="../docker_images"
mkdir -p $OUTPUT_DIR

# Path to the docker-compose.yaml file
DOCKER_COMPOSE_FILE="../docker-compose.yaml"

# Function to extract images from docker-compose.yaml
extract_images() {
  # Use yq or awk/sed to parse docker-compose.yaml for the "image:" lines
  grep "image:" $DOCKER_COMPOSE_FILE | awk '{print $2}' | sort -u
}

# Check if the docker-compose.yaml file exists
if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
  echo "Error: $DOCKER_COMPOSE_FILE not found."
  exit 1
fi

# Extract the list of images
IMAGES=$(extract_images)

if [[ -z "$IMAGES" ]]; then
  echo "No images found in $DOCKER_COMPOSE_FILE."
  exit 1
fi

echo "Starting to download and save container images..."

# Loop through each image and save it
for IMAGE in $IMAGES; do
  echo "Processing image: $IMAGE"
  
  # Pull the image
  docker pull $IMAGE
  
  # Extract the image name and tag
  IMAGE_NAME=$(echo $IMAGE | sed 's/[:\/]/_/g')
  
  # Save the image as a tar file
  docker save $IMAGE -o "$OUTPUT_DIR/$IMAGE_NAME.tar"
  
  echo "Saved $IMAGE to $OUTPUT_DIR/$IMAGE_NAME.tar"
done

echo "All images have been downloaded and saved to the $OUTPUT_DIR directory."
