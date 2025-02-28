#!/bin/bash
set -e

REGISTRY_USERNAME=$1
REGISTRY_PASSWORD=$2
REGISTRY_URL=$3
IMAGES_TXT=$4

echo "Logging in to Docker registry: ${REGISTRY_URL}"
docker login -u ${REGISTRY_USERNAME} -p ${REGISTRY_PASSWORD} ${REGISTRY_URL}

while IFS= read -r image; do
  docker pull "$image"
done < ${IMAGES_TXT}

echo "All images have been pulled successfully."