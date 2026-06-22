FROM alpine:3.18
RUN apk add --no-cache gnucobol gcc libc-dev --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community
WORKDIR /app
COPY client.cob .
COPY socket_helper.c .
RUN cobc -free -x -o bdi_client client.cob socket_helper.c
CMD ["./bdi_client"]
