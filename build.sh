#!/bin/bash

set -e

ORG=burmilla
REPO=elemental-prototype
TAG=20250926-01
IMAGE=$ORG/$REPO:$TAG

docker build . --build-arg VERSION=$TAG -t $IMAGE
docker push $IMAGE
docker tag $IMAGE $ORG/$REPO:latest
docker push $ORG/$REPO:latest

docker run --rm -it -v $(pwd):/build local/elemental-toolkit:v2.2.5 --debug build-iso --bootloader-in-rootfs --extra-cmdline "apparmor=1 security=apparmor" -o /build $IMAGE
