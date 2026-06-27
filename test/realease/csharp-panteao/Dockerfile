FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-env
WORKDIR /App

# Copiar tudo
COPY . ./

# Baixar o pacote Panteao oficial direto do NuGet
# (Isso vai dar erro 404 se a esteira ainda não publicou)
RUN dotnet restore

# Buildar o binário otimizado
RUN dotnet publish -c Release -o out

# Imagem final de runtime (MUITO mais leve)
FROM mcr.microsoft.com/dotnet/runtime:8.0
WORKDIR /App

# Instalar utilitários básicos para o BdiClient conseguir baixar o .tgz do NPM no runtime
RUN apt-get update && apt-get install -y curl tar ca-certificates && rm -rf /var/lib/apt/lists/*

# Copiar os binários do projeto
COPY --from=build-env /App/out .
# Não podemos esquecer dos arquivos do Jason!
COPY --from=build-env /App/project.jcm .
COPY --from=build-env /App/bob.asl .

ENTRYPOINT ["dotnet", "PanteaoTest.dll"]
