# Levantar Seed de Prueba - BSC BackOffice

## Prerequisitos
- Docker y Docker Compose instalados
- El proyecto BSC clonado

## Pasos

### 1. Levantar los contenedores

```bash
cd /ruta/al/proyecto/BSC
docker compose up -d bsc_mongo bsc_backend bsc_frontend bsc_fileserver
```

Esperar ~5 segundos a que MongoDB inicie completamente.

### 2. Ejecutar el seed

```bash
docker exec bsc_mongo mongosh "mongodb://bsc_admin:bsc_pass_2024@localhost:27017/bsc_db?authSource=admin" /seeds/seed_prueba.js
```

Esto limpia la base de datos y crea:
- **3 Roles:** Gerente, Lider, Colaborador
- **15 Colaboradores** con sus roles asignados

### 3. Verificar

Acceder a http://localhost:3000 y seleccionar un usuario.

## Usuarios de prueba

| Nombre | Correo | Rol(es) |
|--------|--------|---------|
| Carlos Mendoza | carlos.mendoza@bsc.com | Gerente |
| Ana Torres | ana.torres@bsc.com | Lider |
| Marco Reyes | marco.reyes@bsc.com | Lider |
| Laura Vega | laura.vega@bsc.com | Lider, Colaborador |
| Diego Paredes | diego.paredes@bsc.com | Lider, Colaborador |
| Sofia Herrera | sofia.herrera@bsc.com | Colaborador |
| Andres Loor | andres.loor@bsc.com | Colaborador |
| Daniela Cruz | daniela.cruz@bsc.com | Colaborador |
| Pablo Salazar | pablo.salazar@bsc.com | Colaborador |
| Camila Flores | camila.flores@bsc.com | Colaborador |
| Ricardo Nunez | ricardo.nunez@bsc.com | Colaborador |
| Valeria Moran | valeria.moran@bsc.com | Colaborador |
| Fernando Diaz | fernando.diaz@bsc.com | Colaborador |
| Isabella Ponce | isabella.ponce@bsc.com | Colaborador |
| Sebastian Aguilar | sebastian.aguilar@bsc.com | Colaborador |

**Password de todos:** `Test1234!`

## Flujo de prueba sugerido

1. **Gerente (Carlos Mendoza):** Crear tareas, asignar a Lideres
2. **Lider (Ana Torres):** Ver tareas asignadas, asignar a Colaboradores, validar entregas
3. **Colaborador (Sofia Herrera):** Ver tareas asignadas, subir evidencias, marcar como completadas
4. **Multi-rol (Laura Vega):** Probar cambio de rol desde el header (Lider ↔ Colaborador)

## Resetear datos

Para volver a ejecutar el seed (limpia todo y reinserta):

```bash
docker exec bsc_mongo mongosh "mongodb://bsc_admin:bsc_pass_2024@localhost:27017/bsc_db?authSource=admin" /seeds/seed_prueba.js
```
