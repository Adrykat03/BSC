# Arquitectura General del Proyecto BSC - MaxPoint BackOffice

## Descripcion del Proyecto
Sistema de gestion BackOffice para MaxPoint/KFC, construido con arquitectura de microservicios containerizada.

## Stack Tecnologico

| Capa | Tecnologia | Version |
|------|-----------|---------|
| Backend API | .NET Core | 8.0 LTS |
| Base de Datos | MongoDB | 7.x |
| Frontend | React | 18.x |
| Contenedores | Docker + Docker Compose | Latest |
| Analisis de Codigo | SonarQube | Community Edition |

## Estructura de Carpetas del Proyecto

```
BSC/
├── lineamientos/            # Documentacion de lineamientos y agentes
├── style/                   # Design system CSS (tokens, componentes, utilities)
├── backend/                 # API .NET Core 8
│   ├── src/
│   │   ├── BSC.API/         # Proyecto Web API (entry point)
│   │   ├── BSC.Application/ # Capa de aplicacion (CQRS, DTOs, interfaces)
│   │   ├── BSC.Domain/      # Capa de dominio (entidades, value objects)
│   │   └── BSC.Infrastructure/ # Capa de infraestructura (MongoDB, servicios externos)
│   ├── tests/
│   │   ├── BSC.UnitTests/
│   │   └── BSC.IntegrationTests/
│   ├── BSC.sln
│   └── Dockerfile
├── frontend/                # Aplicacion React
│   ├── public/
│   ├── src/
│   │   ├── assets/          # Imagenes, fuentes
│   │   ├── components/      # Componentes reutilizables
│   │   ├── pages/           # Paginas/vistas
│   │   ├── hooks/           # Custom hooks
│   │   ├── services/        # Llamadas API
│   │   ├── store/           # Estado global
│   │   ├── styles/          # Estilos importados desde /style
│   │   ├── utils/           # Utilidades
│   │   └── App.jsx
│   ├── package.json
│   └── Dockerfile
├── docker-compose.yml
├── docker-compose.override.yml
├── .gitignore
├── CONTEXTO.md              # Registro de funcionalidades desarrolladas
└── start-pm.bat             # Iniciar Claude como PM
```

## Red Docker

- **Nombre de red:** `bsc_net`
- **Subnet:** `19.168.78.0/24`
- **Gateway:** `19.168.78.1`
- **IPs asignadas:**

| Servicio | IP | Puerto Host | Puerto Container |
|----------|-----|-------------|-----------------|
| MongoDB | 19.168.78.10 | 27017 | 27017 |
| Backend API | 19.168.78.11 | 5000 | 8080 |
| Frontend React | 19.168.78.12 | 3000 | 3000 |
| SonarQube | 19.168.78.13 | 9000 | 9000 |
| SonarQube DB (PostgreSQL) | 19.168.78.14 | 5432 | 5432 |
| Mongo Express (admin) | 19.168.78.15 | 8081 | 8081 |

## Patron Arquitectonico Backend
- **Clean Architecture** con separacion en capas: Domain, Application, Infrastructure, API
- **CQRS simplificado** usando MediatR
- **Repository Pattern** para acceso a MongoDB

## Patron Arquitectonico Frontend
- **Component-Based Architecture** con React
- **Custom Hooks** para logica reutilizable
- **Context API** para estado global (o Zustand si crece)
- **Design System** existente en carpeta `/style` como base de estilos
