# Build stage
FROM mcr.microsoft.com/dotnet/sdk:8.0@sha256:9e9690cacf04e7e37722dfd0c93ad99129df850db79c2947704be0752f3e62ac AS build
WORKDIR /src

# Copiar archivos de proyecto para restaurar dependencias
COPY src/BSC.Domain/BSC.Domain.csproj src/BSC.Domain/
COPY src/BSC.Application/BSC.Application.csproj src/BSC.Application/
COPY src/BSC.Infrastructure/BSC.Infrastructure.csproj src/BSC.Infrastructure/
COPY src/BSC.API/BSC.API.csproj src/BSC.API/

RUN dotnet restore src/BSC.API/BSC.API.csproj

# Copiar todo el código fuente y compilar
COPY src/ src/
RUN dotnet publish src/BSC.API/BSC.API.csproj -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0@sha256:8c7de8ca26baa56530cdc3d55b5563420ee2a302619ad808c53ec64613143771 AS runtime
WORKDIR /app

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

COPY --from=build /app/publish .

RUN adduser --disabled-password --gecos '' appuser
USER appuser

ENTRYPOINT ["dotnet", "BSC.API.dll"]
