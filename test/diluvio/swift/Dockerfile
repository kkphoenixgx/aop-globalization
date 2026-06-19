FROM public.ecr.aws/docker/library/swift:5.9-jammy
WORKDIR /app
COPY client.swift /app/
RUN swiftc client.swift -o client
CMD ["./client"]
