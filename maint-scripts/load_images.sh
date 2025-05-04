#!/bin/bash

# Directory containing the Docker image tar files
IMAGE_DIR="../docker_images"

# Local registry address
LOCAL_REGISTRY="localhost:5000"

# Check if the image directory exists
if [[ ! -d "$IMAGE_DIR" ]]; then
  echo "Error: Directory $IMAGE_DIR does not exist."
  exit 1
fi

# Start loading images
echo "Starting to load Docker images into the local registry ($LOCAL_REGISTRY)..."

# Loop through all tar files in the directory
for TAR_FILE in "$IMAGE_DIR"/*.tar; do
  if [[ -f "$TAR_FILE" ]]; then
    echo "Loading image from $TAR_FILE..."

    # Load the image
    docker load < "$TAR_FILE"

    # Extract the image name and tag from the tar file
    IMAGE_NAME=$(docker load < "$TAR_FILE" | awk '/Loaded image:/ {print $3}')

    if [[ -z "$IMAGE_NAME" ]]; then
      echo "Error: Failed to extract image name from $TAR_FILE."
      continue
    fi

    echo "Image loaded: $IMAGE_NAME"

    # Tag the image for the local registry
    IMAGE_NAME_LOCAL="$LOCAL_REGISTRY/${IMAGE_NAME#*/}" # Remove any existing registry prefix
    docker tag "$IMAGE_NAME" "$IMAGE_NAME_LOCAL"
    echo "Tagged image as: $IMAGE_NAME_LOCAL"

    # Push the image to the local registry
    docker push "$IMAGE_NAME_LOCAL"
    echo "Pushed $IMAGE_NAME_LOCAL to $LOCAL_REGISTRY"
  else
    echo "No tar files found in $IMAGE_DIR."
  fi
done

echo "All images have been loaded into the local registry."
