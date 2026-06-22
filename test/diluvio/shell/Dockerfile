FROM public.ecr.aws/docker/library/bash:5
RUN apk add --no-cache coreutils
WORKDIR /app
COPY sdk sdk
COPY client.sh .
RUN chmod +x client.sh
CMD ["bash", "./client.sh"]
