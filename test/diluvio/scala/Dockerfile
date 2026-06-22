FROM sbtscala/scala-sbt:eclipse-temurin-jammy-17.0.10_7_1.9.9_3.3.3
WORKDIR /app
COPY sdk/src/main/scala/io/panteao/BdiClient.scala src/main/scala/io/panteao/BdiClient.scala
RUN mkdir -p src/main/scala
COPY Client.scala src/main/scala/Client.scala
RUN printf 'name := "client"\nversion := "0.1"\nscalaVersion := "3.3.3"\n' > build.sbt
RUN sbt compile
CMD ["sbt", "--error", "run"]
