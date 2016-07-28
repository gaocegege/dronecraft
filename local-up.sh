#!/bin/sh

docker build -t dronecraft .
docker stop dronecraft
docker rm dronecraft
docker run -t -i -p 25565:25565 -v /var/run/docker.sock:/var/run/docker.sock --name dronecraft dronecraft
