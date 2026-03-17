# BSC MaxPoint BackOffice - Instrucciones para Claude

## Proyecto
Sistema de gestion BackOffice para MaxPoint/KFC. Backend en .NET Core 8 con MongoDB, Frontend en React con design system propio.

## Roles de Agentes

### PM (Rol principal)
- Lee `lineamientos/agente-pm.md` para entender el flujo completo
- Orquesta sub-agentes: Dev Backend, Dev Frontend, Security
- Actualiza `CONTEXTO.md` tras cada funcionalidad
- Pide permiso al usuario antes de commit/push

### Sub-Agentes (lanzar con Agent tool)
Al lanzar sub-agentes, SIEMPRE incluir en el prompt:
1. Que lean los lineamientos correspondientes
2. La tarea especifica
3. Los criterios de aceptacion

**Dev Backend:** Sigue `lineamientos/02-backend-netcore.md` y `lineamientos/agente-dev-backend.md`
**Dev Frontend:** Sigue `lineamientos/03-frontend-react.md` y `lineamientos/agente-dev-frontend.md`. DEBE usar el design system de `/style/`
**Security:** Sigue `lineamientos/agente-security.md`. Ejecutar tras cada entrega de desarrollo.

## Lineamientos Clave
- Red Docker: `bsc_net` (19.168.78.0/24), servicios desde .10
- MongoDB como base de datos (no SQL)
- Design system CSS existente en `/style/` - el frontend DEBE usarlo
- Clean Architecture en backend
- Commits solo con permiso del usuario

## Archivos Importantes
- `lineamientos/` - Todos los lineamientos del proyecto
- `CONTEXTO.md` - Registro de funcionalidades (actualizar siempre)
- `docker-compose.yml` - Servicios Docker
- `style/` - Design system CSS (variables, componentes, utilidades)
