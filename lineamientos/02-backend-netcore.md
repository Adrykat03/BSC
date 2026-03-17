# Lineamientos Backend - .NET Core 8 con MongoDB

## Principios Generales
- **Arquitectura Hexagonal** (Ports & Adapters) para garantizar flexibilidad y desacoplamiento
- Inyeccion de dependencias nativa de .NET
- Async/await en todas las operaciones I/O
- Validaciones con FluentValidation
- Logging estructurado con Serilog
- Manejo global de excepciones via middleware
- **Swagger/OpenAPI** obligatorio para documentacion de todos los endpoints

## Arquitectura Hexagonal

La arquitectura hexagonal separa el dominio de los detalles de infraestructura mediante puertos (interfaces) y adaptadores (implementaciones).

```
                    ┌─────────────────────────────┐
   HTTP Request ──> │  Adaptadores de Entrada      │
   (Controllers)    │  (API Controllers, Filters)  │
                    └──────────┬──────────────────┘
                               │ usa Puertos de Entrada
                    ┌──────────▼──────────────────┐
                    │  Application (Use Cases)      │
                    │  Commands, Queries, Services  │
                    └──────────┬──────────────────┘
                               │ define Puertos de Salida
                    ┌──────────▼──────────────────┐
                    │  Domain (Entidades, VOs)      │
                    │  Reglas de negocio puras       │
                    └──────────┬──────────────────┘
                               │ implementado por
                    ┌──────────▼──────────────────┐
   MongoDB <─────── │  Adaptadores de Salida        │
   APIs Externas    │  (Repositories, Services)     │
                    └─────────────────────────────┘
```

### Capas y Dependencias
- **Domain:** No depende de nada. Contiene entidades, value objects, interfaces de repositorio (puertos de salida)
- **Application:** Depende solo de Domain. Contiene casos de uso, DTOs, validadores, interfaces de servicios (puertos de entrada)
- **Infrastructure:** Implementa los puertos de salida definidos en Domain (adaptadores de salida: repos MongoDB, servicios externos)
- **API:** Adaptadores de entrada. Controllers que invocan casos de uso via puertos de entrada

### Regla de dependencia
Las dependencias SIEMPRE apuntan hacia adentro: API -> Application -> Domain <- Infrastructure

## Swagger / OpenAPI
- **Obligatorio** en todos los endpoints
- Configurar en `Program.cs` con `Swashbuckle.AspNetCore`
- Documentar con atributos: `[ProducesResponseType]`, `[SwaggerOperation]`
- Incluir descripciones en controllers y DTOs con `/// <summary>`
- Agrupar endpoints por controller/tag
- Swagger UI disponible en `/swagger`

## Estructura de la Solucion

### BSC.Domain
Capa de dominio puro, sin dependencias externas.
```
BSC.Domain/
├── Entities/           # Entidades de dominio
├── ValueObjects/       # Value objects
├── Enums/              # Enumeraciones del dominio
├── Exceptions/         # Excepciones de dominio
└── Interfaces/         # Interfaces del dominio (IRepository)
```

### BSC.Application
Logica de aplicacion, orquestacion.
```
BSC.Application/
├── Commands/           # Comandos CQRS (crear, actualizar, eliminar)
├── Queries/            # Consultas CQRS (leer)
├── DTOs/               # Data Transfer Objects
├── Interfaces/         # Interfaces de servicios
├── Mappings/           # Perfiles de AutoMapper
├── Validators/         # Validaciones con FluentValidation
├── Behaviors/          # Pipeline behaviors (logging, validacion)
└── DependencyInjection.cs
```

### BSC.Infrastructure
Implementaciones concretas, acceso a datos.
```
BSC.Infrastructure/
├── Persistence/
│   ├── MongoDbContext.cs
│   ├── Repositories/
│   └── Configurations/  # Mappings de MongoDB
├── Services/            # Implementaciones de servicios externos
└── DependencyInjection.cs
```

### BSC.API
Entry point, controllers, middlewares.
```
BSC.API/
├── Controllers/
├── Middlewares/
│   ├── ExceptionHandlingMiddleware.cs
│   └── RequestLoggingMiddleware.cs
├── Filters/
├── Extensions/
├── Program.cs
├── appsettings.json
└── appsettings.Development.json
```

## Paquetes NuGet Requeridos

```xml
<!-- BSC.API -->
<PackageReference Include="Swashbuckle.AspNetCore" Version="6.*" />
<PackageReference Include="Serilog.AspNetCore" Version="8.*" />
<PackageReference Include="MediatR" Version="12.*" />

<!-- BSC.Application -->
<PackageReference Include="MediatR" Version="12.*" />
<PackageReference Include="AutoMapper.Extensions.Microsoft.DependencyInjection" Version="12.*" />
<PackageReference Include="FluentValidation.DependencyInjectionExtensions" Version="11.*" />

<!-- BSC.Infrastructure -->
<PackageReference Include="MongoDB.Driver" Version="2.*" />
```

## Configuracion MongoDB

```json
{
  "MongoDbSettings": {
    "ConnectionString": "mongodb://bsc_mongo:27017",
    "DatabaseName": "bsc_db"
  }
}
```

### Convencion de nombres en MongoDB
- Colecciones: PascalCase plural (ej: `Products`, `MenuCategories`)
- Campos: camelCase en la base, PascalCase en C#
- IDs: usar `ObjectId` nativo de MongoDB

## Convenciones de Codigo

### Controllers
```csharp
[ApiController]
[Route("api/[controller]")]
public class ProductsController : ControllerBase
{
    private readonly IMediator _mediator;

    [HttpGet]
    [ProducesResponseType(typeof(List<ProductDto>), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetAll([FromQuery] GetProductsQuery query)
    {
        var result = await _mediator.Send(query);
        return Ok(result);
    }
}
```

### Respuestas API Estandar
```csharp
public class ApiResponse<T>
{
    public bool Success { get; set; }
    public string Message { get; set; }
    public T Data { get; set; }
    public List<string> Errors { get; set; }
}
```

### Codigos HTTP
| Operacion | Exito | Error Validacion | No Encontrado | Error Servidor |
|-----------|-------|-----------------|---------------|----------------|
| GET | 200 | 400 | 404 | 500 |
| POST | 201 | 400 | - | 500 |
| PUT | 200 | 400 | 404 | 500 |
| DELETE | 204 | 400 | 404 | 500 |

## Reglas de Negocio
- Toda entidad debe tener campos de auditoria: `CreatedAt`, `CreatedBy`, `UpdatedAt`, `UpdatedBy`
- Soft delete usando campo `IsDeleted` y `DeletedAt`
- Paginacion obligatoria en endpoints de listado
- Maximo 100 registros por pagina

## Testing
- Tests unitarios para Application layer (Commands, Queries, Validators)
- Tests de integracion para Infrastructure (Repositorios contra MongoDB real)
- Naming convention: `MetodoAProbar_Escenario_ResultadoEsperado`
- Usar `WebApplicationFactory` para tests de integracion de la API

## Docker y Compilacion
- Imagen base: `mcr.microsoft.com/dotnet/aspnet:8.0`
- Build image: `mcr.microsoft.com/dotnet/sdk:8.0`
- Multi-stage build para optimizar tamano
- Exponer puerto 8080
- Variables de entorno para configuracion sensible

### Cuando recompilar el backend
El backend se construye como imagen Docker. **Cada vez que se modifique codigo en `backend/`**, se debe reconstruir la imagen:

```bash
docker compose build bsc_backend
docker compose up -d bsc_backend
```

Esto aplica cuando:
- Se agregan/modifican Controllers, Commands, Queries, DTOs, Entities
- Se cambian dependencias NuGet (`.csproj`)
- Se modifican archivos de configuracion (`appsettings.json`, `Program.cs`)
- Se agregan/modifican Middlewares, Validators, Repositories

**No es necesario** recompilar si solo cambian variables de entorno definidas en `docker-compose.yml` (basta con `docker compose up -d bsc_backend`).
