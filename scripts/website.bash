#!/bin/bash
docker container run --rm -v $PWD/config.json:/config.json greenbigfrog/website
