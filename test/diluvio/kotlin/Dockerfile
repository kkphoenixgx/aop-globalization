FROM public.ecr.aws/docker/library/amazoncorretto:17-alpine
WORKDIR /app
RUN apk add --no-cache bash
COPY sdk sdk
COPY kotlinc /app/kotlinc
ENV PATH="${PATH}:/app/kotlinc/bin"
COPY Client.kt /app/
RUN kotlinc sdk/src/main/kotlin/io/panteao/BdiClient.kt Client.kt -include-runtime -d Client.jar
CMD ["java", "-jar", "Client.jar"]
