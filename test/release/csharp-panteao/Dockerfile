FROM mcr.microsoft.com/dotnet/sdk:8.0

WORKDIR /app

COPY . .

# Fazemos o restore para baixar o pacote Panteao do NuGet
RUN dotnet restore

# Rodamos o projeto
CMD ["dotnet", "run"]
