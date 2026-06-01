# Guía de Deploy a Producción — BSC Nomina2

Runbook para releases habituales después del primer despliegue.
Servidor de producción: `192.168.100.9` (usuario `cx`).

---

## Contexto importante

El frontend **NO se compila en el servidor** (no tiene Node instalado).
El flujo correcto es:

```
Local (npm run build) → SCP → Servidor (html/) ← nginx lee en tiempo real
```

Cambios en el **backend** sí se reconstruyen en el servidor con Docker.
Los **stored procedures** se aplican manualmente en SQL Server.

---

## Prerequisito: configurar SSH en la sesión

Si es la primera vez en la sesión de terminal, configura el helper de contraseña
para no tener que escribirla en cada comando:

```bash
echo '#!/bin/bash
echo "jcjajplae*88"' > /tmp/askpass.sh && chmod +x /tmp/askpass.sh

export SSH_ASKPASS=/tmp/askpass.sh
export SSH_ASKPASS_REQUIRE=force
```

Verifica la conexión:

```bash
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "echo OK"
```

---

## 1. Actualizar el código en el servidor

```bash
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "
  git -C ~/BSC pull
  echo '--- Últimos commits ---'
  git -C ~/BSC log --oneline -5
"
```

---

## 2. Deploy del Frontend (obligatorio si hubo cambios en `frontend/`)

### 2a. Compilar localmente

```bash
cd C:/Proyectos/BSC/frontend
npm run build
```

El resultado queda en `frontend/dist/`.

### 2b. Limpiar la carpeta de producción

```bash
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "rm -rf ~/BSC/html/*"
```

### 2c. Subir el build al servidor

```bash
scp -o StrictHostKeyChecking=no -r C:/Proyectos/BSC/frontend/dist/. cx@192.168.100.9:~/BSC/html/
```

> El nginx sirve `~/BSC/html/` como volumen montado — los cambios se aplican
> **inmediatamente** sin reiniciar ningún contenedor.

### 2d. Verificar que llegaron los archivos nuevos

```bash
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "ls -lt ~/BSC/html/assets/*.js | head -5"
```

Las fechas deben ser de hoy.

---

## 3. Deploy del Backend (solo si hubo cambios en `backend/`)

```bash
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "
  cd ~/BSC
  docker compose up -d --build bsc_backend
  docker compose logs bsc_backend --tail=20
"
```

---

## 4. Deploy de Stored Procedures (solo si hubo cambios en `SP/`)

Los archivos `.sql` se ejecutan **manualmente** en SQL Server.
No hay automatización — abrirlos en SSMS y ejecutarlos contra la BD correspondiente
(generalmente `DB_NOMKFC` o `ADAM`, indicado en el encabezado del archivo).

---

## 5. Smoke test

Abrir `http://192.168.100.9:3030` en el navegador y verificar:

- [ ] Login funciona.
- [ ] Cada módulo que tuvo cambios carga correctamente.
- [ ] No hay errores en consola del navegador (F12 → Console).

Si algo no carga, hacer `Ctrl+Shift+R` (recarga sin caché) antes de escalar.

---

## 6. Verificar estado general del servidor

```bash
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "
  echo '--- Contenedores ---'
  docker compose -f ~/BSC/docker-compose.yml ps

  echo ''
  echo '--- Git status ---'
  git -C ~/BSC log --oneline -3
"
```

---

## Rollback del Frontend

Si algo sale mal tras subir el build:

```bash
# Desde local: volver a subir el build anterior
# (si tenías el dist/ de la versión anterior guardado)
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "rm -rf ~/BSC/html/*"
scp -o StrictHostKeyChecking=no -r C:/Proyectos/BSC/frontend/dist-anterior/. cx@192.168.100.9:~/BSC/html/
```

Si no tienes el build anterior, busca el commit previo, haz checkout, rebuild y sube.

---

## Resumen rápido (cheatsheet)

```bash
# 0. Setup SSH (una vez por sesión)
echo '#!/bin/bash
echo "jcjajplae*88"' > /tmp/askpass.sh && chmod +x /tmp/askpass.sh
export SSH_ASKPASS=/tmp/askpass.sh SSH_ASKPASS_REQUIRE=force

# 1. Pull en servidor
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "git -C ~/BSC pull"

# 2. Build + deploy frontend
cd C:/Proyectos/BSC/frontend && npm run build
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "rm -rf ~/BSC/html/*"
scp -o StrictHostKeyChecking=no -r C:/Proyectos/BSC/frontend/dist/. cx@192.168.100.9:~/BSC/html/

# 3. (Opcional) Rebuild backend
ssh -o StrictHostKeyChecking=no cx@192.168.100.9 "cd ~/BSC && docker compose up -d --build bsc_backend"
```

---

## Notas de infraestructura

| Componente | Cómo se actualiza | Requiere reinicio |
|---|---|---|
| Frontend (React) | SCP del `dist/` local a `html/` | No — nginx sirve el volumen en tiempo real |
| Backend (.NET) | `docker compose up -d --build bsc_backend` en servidor | Sí — el contenedor se reconstruye |
| Stored Procedures | Ejecución manual en SSMS | No |
| nginx config | Editar `config/nginx/default.conf` + `docker exec bsc_frontend nginx -s reload` | Solo reload (sin downtime) |
| MongoDB | No requiere acción habitualmente | — |

> **Razón por la que el frontend no se compila en el servidor:** el servidor no
> tiene Node instalado y el docker-compose usa `nginx:alpine` con volumen montado
> en lugar de una imagen custom con build multistage. Decisión tomada en junio 2026
> por simplicidad; migrar a multistage build eliminaría este paso manual.
