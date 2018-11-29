#!/bin/bash
docker container run --rm --network host -v $PWD/config.json:/config.json greenbigfrog/launcher
