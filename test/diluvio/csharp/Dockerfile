FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY sdk sdk
RUN dotnet new console -n Client
WORKDIR /src/Client
COPY Client.cs Program.cs
RUN dotnet add reference ../sdk/Panteao.Client.csproj
RUN dotnet publish -c Release -o /app

FROM mcr.microsoft.com/dotnet/runtime:8.0
WORKDIR /app
COPY --from=build /app .
CMD ["./Client"]
