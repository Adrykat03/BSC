# Dashboard BSC - Excepciones de Promedio Mensual

## Descripcion
Ciertos colaboradores configurados en MongoDB tienen un card adicional "BSC" en su dashboard que muestra el promedio mensual solo de tareas con un titulo especifico. Esas tareas se excluyen de su promedio general.

## Configuracion (MongoDB)
Coleccion: `BscDashboardConfigs`

Documento singleton:
```json
{
  "emails": ["isabella.sanchez@kfc.com.ec", "manuel.zapata@kfc.com.ec"],
  "taskTitlePattern": "Proceso mensual liquidaciones",
  "isActive": true,
  "createdAt": ISODate(),
  "updatedAt": ISODate()
}
```

### Gestionar usuarios
- **Agregar usuario:** Agregar email al array `emails` en MongoDB o Mongo Express (localhost:8081)
- **Quitar usuario:** Remover email del array `emails`
- **Desactivar excepcion:** Cambiar `isActive` a `false`

## Arquitectura

### Backend
| Archivo | Descripcion |
|---------|-------------|
| `Domain/Entities/BscDashboardConfig.cs` | Entidad con emails, taskTitlePattern, isActive |
| `Domain/Interfaces/IBscDashboardConfigRepository.cs` | Interfaz con GetActiveConfigAsync() |
| `Infrastructure/Persistence/Repositories/BscDashboardConfigRepository.cs` | Implementacion MongoDB |
| `Infrastructure/DependencyInjection.cs` | Registro DI del repositorio |
| `API/Controllers/TasksController.cs` | Helper CalculateMonthlyStarsFromTasks, filtro en monthly-stars, endpoints bsc-monthly-stars y has-bsc-dashboard |
| `Application/Queries/GetDashboard/GetDashboardQueryHandler.cs` | Excluye tareas BSC del avg rating general |

### Endpoints
| Metodo | Ruta | Descripcion |
|--------|------|-------------|
| GET | `/api/tasks/has-bsc-dashboard` | Retorna `{ hasBscDashboard: true/false }` segun config |
| GET | `/api/tasks/bsc-monthly-stars` | Estrellas mensuales solo de tareas BSC |
| GET | `/api/tasks/monthly-stars` | Modificado: excluye tareas BSC para usuarios configurados |

### Frontend
| Archivo | Descripcion |
|---------|-------------|
| `services/tasksService.js` | Metodos hasBscDashboard() y getBscMonthlyStars() |
| `pages/Home/Home.jsx` | Estado bscMonthlyStars, fetch condicional, segundo MonthlyStarsCard con label "BSC" |

### Seed
- `seeds/seed_bsc_config.js` - Crea el documento de configuracion inicial

## Notas tecnicas
- El endpoint `GetById("{id}")` usa constraint `{id:length(24)}` para evitar conflicto con rutas BSC
- El helper `CalculateMonthlyStarsFromTasks` es reutilizado por ambos endpoints (general y BSC)
- La comparacion de titulo usa `IndexOf` con `StringComparison.OrdinalIgnoreCase` (case-insensitive)
- El endpoint `has-bsc-dashboard` retorna JSON directo (no wrapeado en ApiResponse)
