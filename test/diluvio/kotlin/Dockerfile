FROM public.ecr.aws/docker/library/amazoncorretto:17-alpine
WORKDIR /app
RUN apk add --no-cache bash
COPY kotlinc /app/kotlinc
ENV PATH="${PATH}:/app/kotlinc/bin"
COPY Client.kt /app/
RUN kotlinc Client.kt -include-runtime -d Client.jar
CMD ["java", "-jar", "Client.jar"]
