FROM golang:1.6.3

# Copy Go code and install applications
COPY ./go /go
RUN cd /go/src/goproxy; go install
RUN cd /go/src/gosetup; go install

# Download Cuberite server (Minecraft C++ server)
# and load up a special empty world for Dockercraft
WORKDIR /srv
COPY ./server/ cuberite_server/
COPY ./world world
COPY ./docs/img/logo64x64.png logo.png
COPY ./scripts/start.sh start.sh
COPY ./docker/docker-1.11.1 /bin/docker-1.11.1

CMD ["/bin/bash","/srv/start.sh"]
