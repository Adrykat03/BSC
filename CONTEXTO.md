# BSC BackOffice - Registro de Funcionalidades

> Este archivo lleva el registro de todas las funcionalidades desarrolladas en el proyecto.
> Se actualiza al finalizar cada iteracion aprobada.

## Indice de Funcionalidades

| ID | Nombre | Estado | Fecha |
|----|--------|--------|-------|
| FUNC-000 | Estructura base del proyecto | Completada | 2026-03-16 |
| FUNC-001 | CRUD Colaboradores | Completada | 2026-03-17 |

---

## Detalle de Funcionalidades

### [FUNC-000] Estructura Base del Proyecto
- **Estado:** Completada
- **Fecha:** 2026-03-16
- **Descripcion:** Creacion de la estructura base del proyecto incluyendo solucion .NET Core 8, proyecto React con Vite, Dockerfiles, y configuracion inicial de MongoDB.
- **Backend:** Solucion BSC.sln con 4 proyectos (API, Application, Domain, Infrastructure). Endpoint GET /api/health retorna "Backend activo". Swagger en /swagger. MongoDB configurado. ExceptionHandlingMiddleware. CORS para localhost:3000.
- **Frontend:** Proyecto Vite + React 18. Layout con sidebar (menu Home) + header + content area. Pagina Home llama a /api/health y muestra resultado. Design system integrado desde /style/. Routing con react-router-dom v6 y lazy loading.
- **Security:** Aprobado. SonarQube configurado (http://localhost:9000). Re-scan limpio: 0 vulnerabilidades, 0 hotspots, 0 code smells en backend. Frontend: 1 code smell menor (contraste CSS). Correcciones aplicadas: credenciales removidas de codigo, Dockerfile con usuario no-root, Swagger condicionado a Development, security headers agregados, exception message generico al cliente.

---

### [FUNC-001] CRUD Colaboradores
- **Estado:** Completada
- **Fecha:** 2026-03-17
- **Descripcion:** Gestion completa de colaboradores del area. Primera entidad del sistema que establece los patrones base (repositorio, validacion, pipeline MediatR) reutilizables en funcionalidades futuras.
- **Backend:**
  - **Entidad:** Colaborador (NombreCompleto, Cedula, Area, Correo, PasswordHash, campos de auditoria CreatedAt/UpdatedAt/IsDeleted/DeletedAt)
  - **Endpoints:** GET /api/colaboradores, GET /api/colaboradores/{id}, POST /api/colaboradores, PUT /api/colaboradores/{id}, DELETE /api/colaboradores/{id}
  - **Patrones base creados:** ValidationBehavior (pipeline MediatR + FluentValidation automatico), ValidationException (400), IPasswordHasher (abstraccion BCrypt), MongoDbMappings (BsonClassMap), soft delete
  - **Validaciones:** Nombre requerido max 100, cedula 10 digitos unica, correo valido unico, password min 8 con complejidad (mayuscula, minuscula, numero, especial)
  - **Seguridad:** Password hasheado con BCrypt via IPasswordHasher, nunca expuesto en DTOs. Soft delete (IsDeleted + DeletedAt). Errores genericos al cliente.
  - **Archivos nuevos (22):** Domain/Entities/Colaborador.cs, Domain/Interfaces/IColaboradorRepository.cs, Domain/Interfaces/IPasswordHasher.cs, Application/DTOs/ColaboradorDto.cs, Application/DTOs/CreateColaboradorDto.cs, Application/DTOs/UpdateColaboradorDto.cs, Application/Exceptions/ValidationException.cs, Application/Behaviors/ValidationBehavior.cs, Application/Features/Colaboradores/ (6 Commands/Queries + Handlers), Application/Validators/CreateColaboradorValidator.cs, Application/Validators/UpdateColaboradorValidator.cs, Infrastructure/Repositories/ColaboradorRepository.cs, Infrastructure/Persistence/MongoDbMappings.cs, Infrastructure/Services/BcryptPasswordHasher.cs, API/Controllers/ColaboradoresController.cs
  - **Archivos modificados:** Application/DependencyInjection.cs (ValidationBehavior pipeline), Infrastructure/DependencyInjection.cs (repositorio + hasher DI), Infrastructure.csproj (BCrypt.Net-Next), Application.csproj (Logging.Abstractions), ExceptionHandlingMiddleware.cs (400 para ValidationException)
- **Frontend:**
  - **Pagina:** Colaboradores.jsx - Tabla con listado, modal crear/editar, dialogo confirmar eliminacion, estados de carga/error/vacio
  - **Componentes comunes (reutilizables):** Modal.jsx, ConfirmDialog.jsx
  - **Servicio:** colaboradorService.js (CRUD via apiClient)
  - **Mejora api.js:** Parseo de errores backend (message + errors array)
  - **Validacion frontend:** Nombre, cedula (10 digitos), area, correo (formato), password (min 8, solo al crear)
  - **Design system:** Usa clases del design system (card, table, btn, form-group, form-input, modal, alert). Sin inline styles.
- **Security:** Aprobado. 0 criticos, 0 altos, 3 medios corregidos (complejidad password, validacion cedula/password frontend), 3 bajos documentados (Authorize pendiente hasta implementar auth, CreatedBy hardcodeado "system" hasta implementar auth, inline style eliminado).

---

<!--
Plantilla para nuevas funcionalidades:

### [FUNC-XXX] Nombre de la Funcionalidad
- **Estado:** Completada | En Progreso | Pendiente
- **Fecha:** YYYY-MM-DD
- **Descripcion:** Breve descripcion de lo que hace la funcionalidad.
- **Backend:** Endpoints, entidades, servicios creados.
- **Frontend:** Paginas, componentes, hooks creados.
- **Security:** Aprobado | Con observaciones | Pendiente
-->
