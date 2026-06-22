FROM public.ecr.aws/docker/library/eclipse-temurin:17-jdk-jammy
WORKDIR /app
COPY sdk sdk
COPY Client.java .
RUN javac -cp sdk/src/main/java sdk/src/main/java/io/panteao/BdiClient.java Client.java
CMD ["java", "-cp", "sdk/src/main/java:.", "Client"]
