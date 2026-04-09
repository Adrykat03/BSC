# Analisis de Seguridad - BSC BackOffice

**Fecha:** 2026-03-17
**Auditor:** Agente de Seguridad BSC
**Veredicto:** NO APROBADO (pendiente de correcciones)

## Resumen

| Severidad | Cantidad |
|-----------|----------|
| Critico   | 2        |
| Alto      | 4        |
| Medio     | 6        |
| Bajo      | 2        |
| Info      | 4        |

---

## Hallazgos

### [CRITICO] H-01 - Credenciales de MongoDB hardcodeadas en docker-compose.yml

- **Archivo:** `docker-compose.yml` lineas 13-14, 37, 134-136
- **Categoria OWASP:** A02 - Cryptographic Failures
- **Descripcion:** Las credenciales de MongoDB (`bsc_admin` / `bsc_pass_2024`) estan en texto plano dentro del docker-compose.yml, asi como la cadena de conexion completa. Tambien las credenciales de Mongo Express. Este archivo esta versionado en git.
- **Recomendacion:** Mover todas las credenciales a un archivo `.env` que este en `.gitignore`. Usar `${VARIABLE}` en docker-compose.yml.

---

### [CRITICO] H-02 - Sin autenticacion ni autorizacion en los endpoints API

- **Archivo:** `backend/src/BSC.API/Controllers/TasksController.cs` (todo el archivo)
- **Archivo:** `backend/src/BSC.API/Program.cs` (no hay `AddAuthentication` ni `UseAuthorization`)
- **Categoria OWASP:** A01 - Broken Access Control / A07 - Identification and Authentication Failures
- **Descripcion:** Ningun endpoint tiene el atributo `[Authorize]`. No hay middleware de autenticacion configurado. El rol del usuario se recibe como parametro del request (query string o body), lo que permite que cualquier usuario no autenticado pueda invocar cualquier endpoint y suplantar cualquier rol.
- **Recomendacion:** Implementar autenticacion (JWT Bearer) y extraer el rol/email del token validado en el servidor, nunca del request body/query. Agregar `[Authorize(Roles = "Gerente")]` en los endpoints correspondientes.

---

### [ALTA] H-03 - Rol del usuario se confia del lado del cliente (Trust Boundary Violation)

- **Archivos:** TasksController.cs lineas 140, 166, 194, 278-283; ChangeTaskStatusCommand.cs linea 15; AssignTaskCommand.cs linea 14; RemoveFileAttachmentCommand.cs lineas 15-16
- **Categoria OWASP:** A01 - Broken Access Control
- **Descripcion:** Los endpoints ChangeStatus, Assign, UploadEvidence y RemoveFile reciben el rol directamente del cliente. Toda la logica de control de acceso por rol depende de este valor que un atacante puede manipular libremente.
- **Recomendacion:** El rol debe obtenerse del token JWT validado en el servidor. Nunca aceptar el rol como parametro del request.

---

### [ALTA] H-04 - Endpoint RemoveFile recibe credenciales sensibles en query string

- **Archivos:** TasksController.cs lineas 278-283; tasksService.js lineas 99-106
- **Categoria OWASP:** A02 - Cryptographic Failures / A01 - Broken Access Control
- **Descripcion:** El endpoint `DELETE /api/tasks/{id}/files/{fileId}` recibe `requesterEmail` y `requesterRole` como query parameters. Los query strings se registran en logs de servidores web, proxies e historial del navegador, exponiendo datos de identidad.
- **Recomendacion:** Mover estos parametros al body del request o obtenerlos del token de autenticacion.

---

### [ALTA] H-05 - File Server (httpd) expone directamente el directorio de archivos sin autenticacion

- **Archivos:** docker-compose.yml lineas 73-83; nginx/default.conf lineas 30-33
- **Categoria OWASP:** A01 - Broken Access Control
- **Descripcion:** El servicio `bsc_fileserver` (httpd) sirve el directorio `/files` completo sin ninguna autenticacion, y nginx lo expone en `/files/`. Cualquier usuario que conozca la estructura de directorios puede navegar y descargar cualquier archivo directamente. El puerto 8082 tambien esta expuesto al host.
- **Recomendacion:** Eliminar el servicio `bsc_fileserver` o agregar autenticacion. Servir archivos exclusivamente a traves del endpoint del backend que ya valida la existencia de la tarea.

---

### [ALTA] H-06 - Endpoint de descarga de archivos sin validacion de permisos

- **Archivo:** TasksController.cs lineas 219-263
- **Categoria OWASP:** A01 - Broken Access Control (IDOR)
- **Descripcion:** El endpoint `GET /api/tasks/{id}/files/{fileId}` no verifica que el usuario solicitante tenga permiso para acceder a los archivos de esa tarea. Cualquier usuario puede descargar cualquier archivo de cualquier tarea conociendo el taskId y fileId.
- **Recomendacion:** Verificar que el usuario autenticado es el creador, lider asignado o colaborador asignado de la tarea antes de permitir la descarga.

---

### [MEDIA] H-07 - Sin Rate Limiting en endpoints

- **Archivo:** Program.cs
- **Categoria OWASP:** A04 - Insecure Design
- **Descripcion:** No se implementa rate limiting en ningun endpoint. Los endpoints de upload de archivos son especialmente susceptibles a abuso por volumen, pudiendo llenar el disco del servidor.
- **Recomendacion:** Implementar `AddRateLimiter` de ASP.NET Core 8 con politicas por endpoint.

---

### [MEDIA] H-08 - No se valida el Content-Type real de los archivos subidos (solo extension)

- **Archivos:** CreateTaskItemCommandHandler.cs lineas 64-65; UpdateTaskItemCommandHandler.cs lineas 66-67, 116-117; UploadEvidenceCommandHandler.cs lineas 80-81
- **Categoria OWASP:** A04 - Insecure Design
- **Descripcion:** La validacion de archivos solo comprueba la extension del nombre del archivo. Un atacante podria subir un archivo ejecutable renombrandolo a `.pdf`.
- **Recomendacion:** Ademas de la extension, validar el Content-Type del IFormFile y los magic bytes (file signature) del contenido.

---

### [MEDIA] H-09 - Archivos huerfanos en disco al eliminar referencias

- **Archivo:** RemoveFileAttachmentCommandHandler.cs lineas 74-75
- **Categoria OWASP:** A04 - Insecure Design
- **Descripcion:** Al eliminar un archivo adjunto, solo se remueve la referencia de MongoDB pero el archivo fisico permanece en el disco y sigue accesible via el file server (H-05).
- **Recomendacion:** Eliminar tambien el archivo fisico del disco, o implementar un proceso batch de limpieza.

---

### [MEDIA] H-10 - Mongo Express sin autenticacion basica expuesto

- **Archivo:** docker-compose.yml lineas 129-144
- **Categoria OWASP:** A05 - Security Misconfiguration
- **Descripcion:** Mongo Express esta configurado con `ME_CONFIG_BASICAUTH: "false"`, deshabilitando la autenticacion basica. Cualquier persona con acceso a la red puede acceder al panel de administracion de MongoDB en el puerto 8081.
- **Recomendacion:** Habilitar `ME_CONFIG_BASICAUTH: "true"` o deshabilitar Mongo Express en produccion.

---

### [MEDIA] H-11 - Puerto de MongoDB expuesto al host

- **Archivo:** docker-compose.yml linea 16
- **Categoria OWASP:** A05 - Security Misconfiguration
- **Descripcion:** MongoDB tiene el puerto 27017 mapeado al host. Con las credenciales hardcodeadas, cualquier usuario en la red local puede conectarse directamente a la base de datos.
- **Recomendacion:** Eliminar el mapeo de puertos en ambientes que no sean desarrollo local.

---

### [MEDIA] H-12 - UpdateTaskItemCommand no valida el rol del solicitante

- **Archivo:** UpdateTaskItemCommandHandler.cs lineas 34-157
- **Categoria OWASP:** A01 - Broken Access Control
- **Descripcion:** El handler de actualizacion de tarea permite modificar todos los campos sin verificar el rol del solicitante. Un Colaborador podria modificar titulo y descripcion que deberian ser solo editables por Gerente/Lider.
- **Recomendacion:** Validar el rol del solicitante y restringir que campos puede modificar cada rol.

---

### [BAJA] H-13 - Inline styles excesivos en componentes React

- **Archivos:** Tasks.jsx, TaskModal.jsx
- **Categoria:** Calidad de codigo
- **Descripcion:** Ambos componentes usan inline styles extensivamente en lugar del design system CSS disponible.
- **Recomendacion:** Migrar los inline styles a clases CSS del design system.

---

### [BAJA] H-14 - Componentes superan las 200 lineas recomendadas

- **Archivos:** Tasks.jsx (798 lineas), TaskModal.jsx (873 lineas)
- **Categoria:** Calidad de codigo
- **Descripcion:** Ambos componentes exceden significativamente el limite de 200 lineas por componente segun los lineamientos.
- **Recomendacion:** Extraer sub-componentes (HistoryModal, FilterToolbar, etc.).

---

### [INFO] H-15 - Swagger habilitado solo en Development (correcto)

- **Archivo:** Program.cs lineas 56-63
- **Descripcion:** Swagger esta correctamente condicionado a Development. Sin observaciones.

---

### [INFO] H-16 - Security headers presentes (correcto)

- **Archivo:** Program.cs lineas 66-73
- **Descripcion:** Se configuran X-Content-Type-Options, X-Frame-Options, X-XSS-Protection y Referrer-Policy. Considerar agregar Content-Security-Policy y Strict-Transport-Security para produccion.

---

### [INFO] H-17 - Path traversal en descarga de archivos correctamente mitigado

- **Archivo:** TasksController.cs lineas 243-251
- **Descripcion:** Se valida path traversal mediante `Path.GetFullPath` y verificacion de directorio base. Implementacion correcta.

---

### [INFO] H-18 - Sanitizacion de nombres de archivo correcta

- **Archivo:** CreateTaskItemCommandHandler.cs linea 84
- **Descripcion:** Se usa `Path.GetFileName(file.FileName)` para sanitizar nombres de archivo. Correcto en los tres handlers de upload.

---

## Acciones recomendadas por prioridad

1. **Implementar autenticacion JWT** (resuelve H-02, H-03, H-04, H-06, H-12)
2. **Mover credenciales a .env** (resuelve H-01)
3. **Eliminar/asegurar bsc_fileserver** (resuelve H-05, H-09)
4. **Autenticacion en Mongo Express** (resuelve H-10)
5. **Rate limiting** (resuelve H-07)
6. **Validar content-type/magic bytes** (resuelve H-08)
