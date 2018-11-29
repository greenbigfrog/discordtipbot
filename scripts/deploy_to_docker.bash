#!/bin/bash
docker image build -t greenbigfrog/dtb-launcher:latest -f docker/Dockerfile.launcher .
docker image build -t greenbigfrog/dtb-website:latest -f docker/Dockerfile.website .
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin
docker push greenbigfrog/dtb-launcher:latest
docker push greenbigfrog/dtb-website:latest