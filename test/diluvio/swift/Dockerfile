FROM public.ecr.aws/docker/library/swift:5.9-jammy
WORKDIR /app
COPY sdk ./sdk
COPY main.swift /app/
RUN swiftc sdk/Sources/PanteaoClient/BdiClient.swift main.swift -o client
CMD ["./client"]
