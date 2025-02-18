#!/bin/bash

# Variables
CHART_PATH="./chart"
VALUES_FILE="./chart/values.yaml"
RENDERED_MANIFESTS="rendered-manifests.yaml"
IMAGES_FILE="images.txt"
OUTPUT_TAR="docker-images-bundle.tar"
AWS_REGION="us-east-1"

# Clean up from previous runs
rm -f "$RENDERED_MANIFESTS" "$IMAGES_FILE" "$OUTPUT_TAR"

# Step 1: Render the Helm chart
echo "Rendering Helm chart..."
helm template dozuki "$CHART_PATH" --values "$VALUES_FILE" > "$RENDERED_MANIFESTS"

# Step 2: Extract images
echo "Extracting image references..."
awk '/image:/ {gsub(/"/, "", $2); print $2}' "$RENDERED_MANIFESTS" | sort -u | grep -E '^[^ ]+:[^ ]+$' > "$IMAGES_FILE"

# Debug: Verify extracted images
echo "Extracted images:"
cat "$IMAGES_FILE"

# Step 3: Authenticate with ECR
echo "Authenticating with AWS ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin 069174876992.dkr.ecr.$AWS_REGION.amazonaws.com
aws ecr-public get-login-password --region us-east-1 | docker login --username AWS --password-stdin public.ecr.aws/h4a0b1e7
aws ecr-public get-login-password \
     --region us-east-1 | docker login \
     --username AWS \
     --password-stdin public.ecr.aws

# Step 4: Pull images locally (force linux/amd64)
echo "Pulling Docker images (linux/amd64)..."
VALID_IMAGES=()  # Initialize an array to hold valid images

while read -r image; do
  if [[ -n "$image" ]]; then # Ensure the image string is not empty
    echo "Pulling image: $image"
    if docker pull --platform linux/amd64 "$image"; then
      echo "Successfully pulled $image"
      # Add the image reference exactly as pulled
      VALID_IMAGES+=("$image")
    else
      echo "Failed to pull $image. Skipping."
    fi
  else
    echo "Skipped invalid or empty image reference."
  fi
done < "$IMAGES_FILE"

# Step 5: Save images to a tar file
if [[ ${#VALID_IMAGES[@]} -eq 0 ]]; then
  echo "Error: No valid images to save. Exiting."
  exit 1
fi

echo "Saving images to $OUTPUT_TAR..."
docker save "${VALID_IMAGES[@]}" -o "$OUTPUT_TAR" || {
  echo "Error: Failed to save images."; exit 1;
}

echo "Images successfully saved to $OUTPUT_TAR."

