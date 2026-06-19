FROM public.ecr.aws/docker/library/dart:stable
WORKDIR /app
COPY client.dart /app/
RUN dart compile exe client.dart -o client
CMD ["./client"]
