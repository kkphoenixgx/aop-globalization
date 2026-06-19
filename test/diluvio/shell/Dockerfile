FROM public.ecr.aws/docker/library/alpine:3.19
RUN apk add --no-cache bash
WORKDIR /app
COPY client.sh /app/
RUN chmod +x client.sh
CMD ["/bin/bash", "/app/client.sh"]
