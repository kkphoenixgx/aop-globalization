FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-env
WORKDIR /App

COPY . ./

RUN dotnet restore

RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/runtime:8.0

WORKDIR /App

RUN apt-get update && apt-get install -y curl tar ca-certificates && rm -rf /var/lib/apt/lists/*

COPY --from=build-env /App/out .

COPY --from=build-env /App/project.jcm .
COPY --from=build-env /App/bob.asl .

ENTRYPOINT ["dotnet", "PanteaoTest.dll"]