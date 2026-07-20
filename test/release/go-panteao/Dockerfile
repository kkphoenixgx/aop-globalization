FROM golang:1.21
WORKDIR /app
COPY . .
RUN go mod init testapp && go get github.com/kkphoenixgx/panteao/sdk/go
CMD ["go", "run", "main.go"]
