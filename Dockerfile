# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY ["InPoint.csproj", "./"]
RUN dotnet restore "InPoint.csproj"

COPY . .
RUN dotnet publish "InPoint.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
ENV TZ=Asia/Taipei
EXPOSE 8080

ENTRYPOINT ["dotnet", "InPoint.dll"]
