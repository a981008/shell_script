#!/bin/bash
set -e

REGISTRY_USERNAME=$1
REGISTRY_PASSWORD=$2
REGISTRY_URL=$3
IMAGE_PREFIX=$4
IMAGES_TXT=$5
IMAGES_DIR=$6

echo -n > ${IMAGES_TXT}

echo "Logging in to Docker registry: ${REGISTRY_URL}"
docker login -u ${REGISTRY_USERNAME} -p ${REGISTRY_PASSWORD} ${REGISTRY_URL}

echo "Scanning for Docker images in: ${IMAGES_DIR}"
find ${IMAGES_DIR} -type f -name "*.tar" | while read -r image_tar; do
    echo "Importing image from $image_tar ..."
    docker load -i "$image_tar"
done

IMAGE_NAMES=$(docker images --format "{{.Repository}}:{{.Tag}}")
for IMAGE_NAME in $IMAGE_NAMES; do
    IMAGE_BASENAME=$(echo "$IMAGE_NAME" | awk -F'/' '{print $NF}')
    TARGET_IMAGE="${REGISTRY_URL}/${IMAGE_PREFIX}/${IMAGE_BASENAME}"
    echo "Tagging and pushing image: $IMAGE_NAME -> $TARGET_IMAGE"
    docker tag "$IMAGE_NAME" "$TARGET_IMAGE"
    docker push "$TARGET_IMAGE"
    docker rmi "$TARGET_IMAGE"
    docker rmi "$IMAGE_NAME"
    echo "$TARGET_IMAGE" >> ${IMAGES_TXT}
done

echo "All images have been pushed successfully."