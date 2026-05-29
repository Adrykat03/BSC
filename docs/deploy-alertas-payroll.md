# Deploy de Alertas Payroll + DAB a producción

Runbook para el **primer despliegue** del módulo Alertas Payroll y la puesta en marcha de DAB en el servidor de producción. Y plan abreviado para releases posteriores.

> **Estado al 2026-04-22:** pendiente de ejecutar. Todo el código y la BD están listos; falta subirlo al servidor APP.

## Contexto

Este deploy es el **primer release** que incluye:
- Módulo frontend "Alertas Payroll" (tabla con sort/filtros/sticky + modal de previsualización HTML con zoom).
- Primer stand-up del contenedor `bsc_dab` (Data API Builder) en el servidor APP.
- Consumo de la tabla SQL `Avisos.notificacionesConsolidadas` desde el frontend vía DAB.

Arquitectura efectiva en producción:

```
Servidor APP (nginx + frontend + backend + bsc_dab)
          │
          │  bsc_dab con SQL_CONN → apunta a ↓
          ▼
Servidor SQL PROD (BD de nómina)
```

## Estado de pre-requisitos

| Pieza | Estado | Notas |
|---|---|---|
| SQL prod: constraint acepta `'P'` | ✅ Aplicado | ALTER manual hecho directo en la BD; script versionado: `scripts/002_alter_estado_agregar_p.sql` |
| Código frontend | ✅ En repo local | Probado en entorno local contra DAB local |
| Config DAB (`dab/dab-config.json`) | ✅ En repo | Incluye entity `NotificacionesConsolidadas` |
| Contenedor `bsc_dab` en APP prod | ❌ No existe | Primera vez que se levanta |
| Ruta nginx `/dab/` en APP prod | ⚠️ Verificar | Está en `config/nginx/default.conf` del repo; confirmar que el montado en prod lo tiene |
| Variable `SQL_CONN` en `.env` de APP prod | ❌ No existe | Hay que agregarla |
| Usuarios activos en prod | ✅ Sí | La app ya está en producción con otras pantallas — deploy "en caliente" |
| Exposición de la app | 🟢 Red interna | Aceptable mantener DAB con auth Simulator + anonymous (deuda técnica, ver abajo) |

## Orden del deploy (crítico)

1. Preparar `.env` y config.
2. **Levantar DAB primero** (adición pura, los usuarios no lo usan todavía → sin riesgo).
3. Verificar DAB antes de tocar el frontend.
4. **Después** deploy del frontend (único paso con impacto visible).
5. Smoke test.

## Plan paso a paso

### T-0 — Antes de tocar nada

Coordinación:
- Elegir ventana de **baja actividad** (ej. almuerzo, fin de jornada, antes del inicio del turno).
- Avisar internamente: "Deploy en curso, si algo no carga hagan F5."

Técnico:
```bash
# Backup del html actual (para rollback del frontend)
cp -r /ruta/al/repo/html /ruta/al/repo/html.backup-$(date +%Y%m%d-%H%M)

# Verificar estado de contenedores
docker ps
# Esperado: bsc_frontend, bsc_backend, bsc_mongo, bsc_mongoexpress, bsc_fileserver UP
# Esperado: bsc_dab NO existe aún

# Verificar que bsc_net existe
docker network ls | grep bsc_net
```

Agregar al `.env` del servidor APP (reemplazar valores reales):
```bash
SQL_CONN=Server=<servidor-sql-prod>;Database=DB_NOMKFC;User Id=<user-dab>;Password=<pass>;TrustServerCertificate=True;
```

> **Importante:** crear un **usuario SQL dedicado** para DAB (no usar `sa` ni cuenta de humano). Permisos mínimos: `SELECT`, `INSERT`, `UPDATE`, `DELETE` sobre `Avisos.notificacionesConsolidadas`. Nada más.

### T+0 — Levantar `bsc_dab`

```bash
docker pull mcr.microsoft.com/azure-databases/data-api-builder:latest

docker run -d \
  --name bsc_dab \
  --network bsc_net \
  -p 5555:5000 \
  --env-file /ruta/al/repo/.env \
  -v /ruta/al/repo/dab/dab-config.json:/App/dab-config.json:ro \
  --restart unless-stopped \
  mcr.microsoft.com/azure-databases/data-api-builder:latest
```

### T+1 — Verificar DAB (sin afectar a usuarios)

```bash
# Logs — buscar mensaje de arranque correcto
docker logs bsc_dab | tail -40

# Query de prueba directa al contenedor
curl "http://localhost:5555/api/NotificacionesConsolidadas?\$first=1"
```

Resultado esperado: `{"value":[{...}]}` con una fila real, o `{"value":[]}` si la tabla está vacía.

Errores comunes y qué revisar:
| Error | Causa probable | Fix |
|---|---|---|
| `Cannot connect to server` | `SQL_CONN` incorrecto o firewall APP→SQL cerrado | Revisar connection string y reglas de red |
| `Login failed for user` | Credenciales mal o usuario no existe | Crear/arreglar el usuario SQL |
| `The certificate is not trusted` | Falta `TrustServerCertificate=True` | Agregar al `SQL_CONN` |
| `Invalid object name 'Avisos.notificacionesConsolidadas'` | DAB apunta a BD equivocada | Verificar `Database=...` del `SQL_CONN` |

**Si algo falla aquí: para el deploy.** Los usuarios siguen usando la versión anterior sin saber que hubo un intento. Arregla, prueba, retoma.

### T+2 — Confirmar nginx `/dab/`

Verifica que el `config/nginx/default.conf` montado en el contenedor tiene:
```nginx
location /dab/ {
    proxy_pass http://bsc_dab:5000/api/;
    ...
}
```

Si el archivo de prod era una versión vieja (sin la ruta `/dab/`), reemplázalo por la versión del repo y recarga:
```bash
docker exec bsc_frontend nginx -t     # valida sintaxis
docker exec bsc_frontend nginx -s reload
```

`nginx -s reload` mantiene conexiones activas — **cero downtime** si solo cambió la config.

Prueba desde el host:
```bash
curl "http://localhost:3030/dab/NotificacionesConsolidadas?\$first=1"
```

### T+3 — Deploy del frontend (único paso visible a usuarios)

```bash
cd /ruta/al/repo/frontend
npx vite build

# Sobrescribir el html montado en nginx
rm -rf ../html/assets
cp -r dist/assets ../html/
cp dist/index.html ../html/index.html

# Reload en vez de restart: menor impacto a usuarios activos
docker exec bsc_frontend nginx -s reload
```

Impacto en usuarios activos:
- Quien tenga la SPA cargada en memoria y navegue por páginas sin chunks lazy: **no nota nada**.
- Quien haga click en una ruta que requiera cargar un chunk con hash viejo: recibe error de chunk-load. **F5 lo arregla** (porque `index.html` se sirve con `no-cache` — ver `default.conf` línea 45).

### T+4 — Smoke test end-to-end

Desde cualquier cliente de la red interna, abrir la URL del sistema y verificar:

- [ ] `/` carga normal → el resto de la app no se rompió.
- [ ] Login funciona.
- [ ] `/alertas-payroll` carga la tabla con datos reales.
- [ ] Los KPIs y gráficos muestran cifras coherentes.
- [ ] Click en 👁️ → modal abre → HTML del correo se renderiza visualmente.
- [ ] Zoom +/- en el modal funciona, `Ctrl+wheel` también.
- [ ] Click en ✏️ → cambiar estado a **"En Proceso"** → guardar → se guarda sin error.
  > Este test en particular valida la cadena completa: UI → nginx → DAB → SQL → constraint acepta `P`.
- [ ] Sort clickeando en cabeceras funciona.
- [ ] Filtro global + filtros por columna funcionan.

### T+5 — Post-deploy

- [ ] Agregar entrada a `docs/bitacora.md` con fecha absoluta de lanzamiento, quién lo hizo, resultado del smoke test.
- [ ] Eliminar el backup del html si todo está estable (esperar 24-48h por precaución).
- [ ] Confirmar con los usuarios que ven Alertas Payroll y pueden resolver alertas reales.

## Rollback

### Si el frontend rompe algo (no carga / errores visibles)

```bash
# En el servidor APP
rm -rf /ruta/al/repo/html/assets /ruta/al/repo/html/index.html
cp -r /ruta/al/repo/html.backup-<fecha>/* /ruta/al/repo/html/
docker exec bsc_frontend nginx -s reload
```

### Si DAB no funciona pero el frontend ya está desplegado

Opción 1 — bajar solo DAB, el frontend sigue pero `/alertas-payroll` falla al cargar:
```bash
docker stop bsc_dab && docker rm bsc_dab
```

Opción 2 — rollback completo del frontend (quita Alertas Payroll de la UI):
Ver bloque de arriba.

### La BD SQL no necesita rollback

El `ALTER` del estado `P` es aditivo. Si hubiera `P` guardados y quisieras volver a la constraint vieja, primero tendrías que purgar esas filas — en la práctica, no se hace rollback de este cambio.

## Releases posteriores del mismo módulo (solo frontend)

Una vez que DAB ya esté en prod estable, los siguientes releases de Alertas Payroll son mucho más simples. Plan corto:

```bash
# 1. Backup
cp -r html html.backup-$(date +%Y%m%d-%H%M)

# 2. Build
cd frontend && npx vite build

# 3. Deploy
rm -rf ../html/assets && cp -r dist/assets ../html/
cp dist/index.html ../html/index.html
docker exec bsc_frontend nginx -s reload

# 4. Smoke test + eliminar backup tras 24h
```

TODO pendiente: empaquetar esto en un `npm run deploy` del `frontend/package.json`.

## Deuda técnica conocida a registrar después del deploy

Ver también [bitacora.md](bitacora.md) y [integracion-dab.md](integracion-dab.md).

1. **Seguridad de DAB:** `authentication.provider: Simulator` + `anonymous: create/read/update/delete`. Aceptable porque la app es **red interna**. A endurecer en fase 2:
   - Cambiar provider a `Jwt` con el mismo secreto del backend .NET.
   - Quitar permisos anónimos, dejar solo `authenticated`.
   - Restringir por role (ej. solo usuarios con rol Gerente pueden `update`).
2. **DAB fuera del compose:** `bsc_dab` no está declarado en `docker-compose.yml` — se opera manualmente. Decisión intencional por ahora.
3. **Script 001 desalineado con la BD real:** la constraint vieja sigue en `scripts/001_...sql`. El `002_...sql` ya cubre el gap si alguien monta la BD de cero, pero convendría alguna vez actualizar el 001 directamente. Opcional.
4. **Altura base del iframe (1100px) es arbitraria:** si algún correo real se ve mal, ajustar `BASE_H` en `PreviewModal`.
5. **Manejo de errores de PATCH en UI:** el mensaje de error que ve el usuario es crudo (`Error 500: ...`). Si DAB falla por cualquier motivo, vale la pena un mensaje más amigable.
