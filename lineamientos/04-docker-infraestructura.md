# Lineamientos Docker e Infraestructura

## Red Docker

| Parametro | Valor |
|-----------|-------|
| Nombre | `bsc_net` |
| Driver | bridge |
| Subnet | `19.168.78.0/24` |
| Gateway | `19.168.78.1` |

## Servicios y Asignacion de IPs

| Servicio | Nombre Container | IP | Puerto Host:Container |
|----------|-----------------|-----|----------------------|
| MongoDB | bsc_mongo | 19.168.78.10 | 27017:27017 |
| Backend API | bsc_backend | 19.168.78.11 | 5000:8080 |
| Frontend React | bsc_frontend | 19.168.78.12 | 3000:3000 |
| SonarQube | bsc_sonarqube | 19.168.78.13 | 9000:9000 |
| SonarQube DB | bsc_sonardb | 19.168.78.14 | 5432:5432 |
| Mongo Express | bsc_mongoexpress | 19.168.78.15 | 8081:8081 |

## Volumenes
- `bsc_mongo_data` - Persistencia de datos MongoDB
- `bsc_sonarqube_data` - Datos de SonarQube
- `bsc_sonarqube_extensions` - Extensiones de SonarQube
- `bsc_sonardb_data` - Datos PostgreSQL de SonarQube

## Variables de Entorno

### MongoDB
```
MONGO_INITDB_ROOT_USERNAME=bsc_admin
MONGO_INITDB_ROOT_PASSWORD=bsc_pass_2024
MONGO_INITDB_DATABASE=bsc_db
```

### Backend
```
ASPNETCORE_ENVIRONMENT=Development
MongoDbSettings__ConnectionString=mongodb://bsc_admin:bsc_pass_2024@bsc_mongo:27017
MongoDbSettings__DatabaseName=bsc_db
```

### Frontend
```
VITE_API_URL=http://localhost:5000/api
```

### SonarQube
```
SONAR_JDBC_URL=jdbc:postgresql://bsc_sonardb:5432/sonarqube
SONAR_JDBC_USERNAME=sonarqube
SONAR_JDBC_PASSWORD=sonarqube_pass
```

## Orden de Arranque
1. `bsc_mongo` (sin dependencias)
2. `bsc_sonardb` (sin dependencias)
3. `bsc_backend` (depende de `bsc_mongo`)
4. `bsc_frontend` (depende de `bsc_backend`)
5. `bsc_sonarqube` (depende de `bsc_sonardb`)
6. `bsc_mongoexpress` (depende de `bsc_mongo`)

## Comandos Utiles
```bash
# Levantar todos los servicios
docker compose up -d

# Levantar solo backend + mongo
docker compose up -d bsc_mongo bsc_backend

# Levantar solo frontend
docker compose up -d bsc_frontend

# Ver logs
docker compose logs -f bsc_backend

# Rebuild de un servicio
docker compose up -d --build bsc_backend

# Detener todo
docker compose down

# Detener y eliminar volumenes
docker compose down -v
```
