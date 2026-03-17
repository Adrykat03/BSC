"""
BSC BackOffice - Generador de tareas de prueba para estadísticas
================================================================
Genera ~400 tareas con diferentes estados, tiempos y asignaciones
para tener datos variados en el dashboard.

Requisitos:
    pip install pymongo

Ejecutar:
    python seeds/seed_tareas_estadisticas.py

Nota: Requiere que MongoDB esté corriendo y que el seed base
(seed_prueba.js) ya haya sido ejecutado.
"""

import random
from datetime import datetime, timedelta
from pymongo import MongoClient
from bson import ObjectId

# ============================================
# CONEXIÓN
# ============================================
MONGO_URI = "mongodb://bsc_admin:bsc_pass_2024@localhost:27017/bsc_db?authSource=admin"
client = MongoClient(MONGO_URI)
db = client["bsc_db"]

# ============================================
# CARGAR COLABORADORES Y ROLES EXISTENTES
# ============================================
roles = {r["name"]: str(r["_id"]) for r in db.Roles.find({"isDeleted": False})}
print(f"Roles encontrados: {list(roles.keys())}")

colaboradores = list(db.Colaboradores.find({"IsDeleted": False}))
print(f"Colaboradores encontrados: {len(colaboradores)}")

# Clasificar por rol
gerentes = [c for c in colaboradores if roles["Gerente"] in c["RolIds"]]
lideres = [c for c in colaboradores if roles["Lider"] in c["RolIds"]]
colaboradores_rol = [c for c in colaboradores if roles["Colaborador"] in c["RolIds"]]

print(f"  Gerentes: {len(gerentes)}")
print(f"  Líderes: {len(lideres)}")
print(f"  Colaboradores: {len(colaboradores_rol)}")

if not gerentes or not lideres or not colaboradores_rol:
    print("ERROR: Faltan usuarios. Ejecuta primero seed_prueba.js")
    exit(1)

# ============================================
# CONFIGURACIÓN DE GENERACIÓN
# ============================================
TOTAL_TAREAS = 400
NOW = datetime(2026, 3, 17, 10, 0, 0)

# Distribución de estados (aproximada)
DISTRIBUCION = {
    "Creada": 30,
    "Asignada": 70,
    "Completa - Por Validar": 50,
    "Reasignada": 25,
    "Completa - Validada": 40,
    "Completa": 150,
    "Cancelada": 35,
}

# Títulos de tareas por área
TITULOS = {
    "Tecnologia": [
        "Actualizar dependencias del servidor",
        "Configurar monitoreo de logs",
        "Migrar base de datos a nueva versión",
        "Implementar endpoint de reportes",
        "Corregir bug en módulo de autenticación",
        "Optimizar consultas de rendimiento",
        "Revisar certificados SSL",
        "Automatizar despliegue CI/CD",
        "Documentar API REST",
        "Crear script de respaldo automático",
        "Refactorizar servicio de notificaciones",
        "Integrar pasarela de pagos",
        "Configurar balanceador de carga",
        "Implementar caché Redis",
        "Auditar permisos de base de datos",
    ],
    "Operaciones": [
        "Revisar inventario de equipos",
        "Actualizar procedimiento de incidentes",
        "Coordinar mantenimiento de servidores",
        "Elaborar reporte mensual de operaciones",
        "Verificar cumplimiento de SLAs",
        "Documentar procesos operativos",
        "Capacitar equipo en nuevo sistema",
        "Evaluar proveedores de hosting",
        "Planificar migración de datacenter",
        "Revisar plan de contingencia",
        "Actualizar matriz de escalamiento",
        "Coordinar ventana de mantenimiento",
        "Validar respaldos de información",
        "Configurar alertas de monitoreo",
        "Revisar contratos de servicio",
    ],
    "Calidad": [
        "Ejecutar pruebas de regresión",
        "Documentar casos de prueba",
        "Revisar estándares de código",
        "Elaborar reporte de calidad mensual",
        "Validar criterios de aceptación",
        "Auditar proceso de desarrollo",
        "Crear plan de pruebas automatizadas",
        "Revisar métricas de defectos",
        "Capacitar en mejores prácticas QA",
        "Evaluar herramientas de testing",
        "Certificar release para producción",
        "Documentar hallazgos de auditoría",
        "Revisar cobertura de pruebas",
        "Validar rendimiento bajo carga",
        "Actualizar checklist de despliegue",
    ],
    "Proyectos": [
        "Elaborar cronograma del proyecto",
        "Actualizar tablero de seguimiento",
        "Coordinar reunión de kickoff",
        "Documentar lecciones aprendidas",
        "Revisar presupuesto del proyecto",
        "Elaborar informe de avance semanal",
        "Gestionar riesgos identificados",
        "Actualizar matriz de responsabilidades",
        "Coordinar entregables con cliente",
        "Revisar alcance del proyecto",
        "Planificar sprint de desarrollo",
        "Documentar requerimientos funcionales",
        "Evaluar cambios de alcance",
        "Preparar presentación para stakeholders",
        "Cerrar fase del proyecto",
    ],
}

AREAS = list(TITULOS.keys())


def random_date(start_days_ago, end_days_ago=0):
    """Genera fecha aleatoria entre start_days_ago y end_days_ago días atrás."""
    delta = random.randint(end_days_ago, start_days_ago)
    return NOW - timedelta(days=delta, hours=random.randint(0, 23), minutes=random.randint(0, 59))


def pick_person(people):
    """Elige una persona aleatoria de la lista."""
    p = random.choice(people)
    return {
        "id": str(p["_id"]),
        "name": p["NombreCompleto"],
        "email": p["Correo"],
    }


def make_status_change(from_st, to_st, person, changed_at, comment=None):
    """Crea un registro de cambio de estado con campos camelCase (BsonElement)."""
    return {
        "fromStatus": from_st,
        "toStatus": to_st,
        "changedById": person["id"],
        "changedByName": person["name"],
        "changedByEmail": person["email"],
        "changedAt": changed_at,
        "comment": comment,
    }


def generate_task(status, index):
    """Genera una tarea con el estado dado y datos realistas."""
    gerente = pick_person(gerentes)
    lider = pick_person(lideres)
    colaborador = pick_person(colaboradores_rol)
    area = random.choice(AREAS)
    titulo_base = random.choice(TITULOS[area])
    titulo = f"{titulo_base} #{index}"

    # Fecha de creación: entre 90 y 5 días atrás
    created_at = random_date(90, 5)

    # Tiempo estimado: entre 1 y 40 horas
    estimated_time = round(random.uniform(1, 40), 1)

    # DueDate: entre 3 y 30 días después de creación
    due_delta = timedelta(days=random.randint(3, 30))
    due_date = created_at + due_delta

    # Inicializar tarea base con campos camelCase (match BsonElement attributes)
    task = {
        "title": titulo,
        "description": f"Tarea de {area.lower()}: {titulo_base.lower()}. Prioridad según planificación del sprint.",
        "status": status,
        "assignedLeaderId": None,
        "assignedLeaderName": None,
        "assignedLeaderEmail": None,
        "assignedToId": None,
        "assignedToName": None,
        "assignedToEmail": None,
        "dueDate": due_date,
        "estimatedTime": estimated_time,
        "actualTime": None,
        "insumos": None,
        "insumoFiles": [],
        "evidenceFiles": [],
        "evidenceText": None,
        "statusHistory": [],
        "createdAt": created_at,
        "createdBy": gerente["email"],
        "updatedAt": created_at,
        "updatedBy": gerente["email"],
        "isDeleted": False,
        "deletedAt": None,
    }

    history = []
    current_time = created_at

    # ---- Construir historia según estado final ----

    if status == "Creada":
        # Solo creada, sin asignar
        pass

    elif status == "Asignada":
        # Asignada a líder y colaborador
        current_time += timedelta(hours=random.randint(1, 48))
        history.append(make_status_change("Creada", "Asignada", gerente, current_time, "Asignada para ejecución"))
        task["assignedLeaderId"] = lider["id"]
        task["assignedLeaderName"] = lider["name"]
        task["assignedLeaderEmail"] = lider["email"]
        # 70% ya tienen colaborador asignado
        if random.random() < 0.7:
            task["assignedToId"] = colaborador["id"]
            task["assignedToName"] = colaborador["name"]
            task["assignedToEmail"] = colaborador["email"]

    elif status == "Completa - Por Validar":
        # Fue asignada y el colaborador la completó
        current_time += timedelta(hours=random.randint(1, 24))
        history.append(make_status_change("Creada", "Asignada", gerente, current_time))
        task["assignedLeaderId"] = lider["id"]
        task["assignedLeaderName"] = lider["name"]
        task["assignedLeaderEmail"] = lider["email"]
        task["assignedToId"] = colaborador["id"]
        task["assignedToName"] = colaborador["name"]
        task["assignedToEmail"] = colaborador["email"]

        # Colaborador completa
        work_hours = random.uniform(estimated_time * 0.5, estimated_time * 1.8)
        current_time += timedelta(hours=int(work_hours))
        task["actualTime"] = round(work_hours, 1)
        history.append(make_status_change("Asignada", "Completa - Por Validar", colaborador, current_time, "Trabajo completado, pendiente validación"))
        task["evidenceText"] = "Evidencia adjunta del trabajo realizado."

    elif status == "Reasignada":
        # Fue completada pero rechazada por el líder
        current_time += timedelta(hours=random.randint(1, 24))
        history.append(make_status_change("Creada", "Asignada", gerente, current_time))
        task["assignedLeaderId"] = lider["id"]
        task["assignedLeaderName"] = lider["name"]
        task["assignedLeaderEmail"] = lider["email"]
        task["assignedToId"] = colaborador["id"]
        task["assignedToName"] = colaborador["name"]
        task["assignedToEmail"] = colaborador["email"]

        current_time += timedelta(hours=random.randint(4, 72))
        task["actualTime"] = round(random.uniform(2, 20), 1)
        history.append(make_status_change("Asignada", "Completa - Por Validar", colaborador, current_time))

        current_time += timedelta(hours=random.randint(2, 48))
        history.append(make_status_change("Completa - Por Validar", "Reasignada", lider, current_time, "Requiere correcciones"))

    elif status == "Completa - Validada":
        # Validada por líder, pendiente aprobación final del gerente
        current_time += timedelta(hours=random.randint(1, 24))
        history.append(make_status_change("Creada", "Asignada", gerente, current_time))
        task["assignedLeaderId"] = lider["id"]
        task["assignedLeaderName"] = lider["name"]
        task["assignedLeaderEmail"] = lider["email"]
        task["assignedToId"] = colaborador["id"]
        task["assignedToName"] = colaborador["name"]
        task["assignedToEmail"] = colaborador["email"]

        work_hours = random.uniform(estimated_time * 0.6, estimated_time * 1.5)
        current_time += timedelta(hours=int(work_hours))
        task["actualTime"] = round(work_hours, 1)
        history.append(make_status_change("Asignada", "Completa - Por Validar", colaborador, current_time))
        task["evidenceText"] = "Trabajo completado según especificaciones."

        current_time += timedelta(hours=random.randint(2, 48))
        history.append(make_status_change("Completa - Por Validar", "Completa - Validada", lider, current_time, "Validado correctamente"))

    elif status == "Completa":
        # Flujo completo: creada -> asignada -> completada -> validada -> completa
        current_time += timedelta(hours=random.randint(1, 24))
        history.append(make_status_change("Creada", "Asignada", gerente, current_time))
        task["assignedLeaderId"] = lider["id"]
        task["assignedLeaderName"] = lider["name"]
        task["assignedLeaderEmail"] = lider["email"]
        task["assignedToId"] = colaborador["id"]
        task["assignedToName"] = colaborador["name"]
        task["assignedToEmail"] = colaborador["email"]

        # Decidir si fue a tiempo o tarde
        is_late = random.random() < 0.35  # 35% terminaron tarde

        if is_late:
            # Tardó más que el estimado y/o pasó la fecha límite
            work_hours = random.uniform(estimated_time * 1.2, estimated_time * 2.5)
            current_time += timedelta(hours=int(work_hours))
            # Asegurar que la fecha de completado es después del due_date
            if current_time < due_date:
                current_time = due_date + timedelta(days=random.randint(1, 10))
        else:
            # A tiempo
            work_hours = random.uniform(estimated_time * 0.4, estimated_time * 1.1)
            current_time += timedelta(hours=int(work_hours))
            # Asegurar que no pasa del due_date
            if current_time > due_date:
                current_time = due_date - timedelta(days=random.randint(0, 3), hours=random.randint(1, 12))

        task["actualTime"] = round(work_hours, 1)
        history.append(make_status_change("Asignada", "Completa - Por Validar", colaborador, current_time))
        task["evidenceText"] = "Evidencia completa del trabajo realizado."

        # Algunos pasaron por reasignación (20%)
        if random.random() < 0.2:
            current_time += timedelta(hours=random.randint(2, 24))
            history.append(make_status_change("Completa - Por Validar", "Reasignada", lider, current_time, "Observaciones menores"))
            current_time += timedelta(hours=random.randint(4, 48))
            extra_hours = random.uniform(1, 8)
            task["actualTime"] = round(task["actualTime"] + extra_hours, 1)
            history.append(make_status_change("Reasignada", "Completa - Por Validar", colaborador, current_time, "Correcciones aplicadas"))

        current_time += timedelta(hours=random.randint(2, 48))
        history.append(make_status_change("Completa - Por Validar", "Completa - Validada", lider, current_time, "Validación OK"))

        current_time += timedelta(hours=random.randint(1, 24))
        history.append(make_status_change("Completa - Validada", "Completa", gerente, current_time, "Aprobada"))

    elif status == "Cancelada":
        # Cancelada en algún punto del flujo
        cancel_from = random.choice(["Creada", "Asignada", "Completa - Por Validar"])

        if cancel_from == "Creada":
            current_time += timedelta(hours=random.randint(1, 72))
            history.append(make_status_change("Creada", "Cancelada", gerente, current_time, "Cancelada por cambio de prioridades"))

        elif cancel_from == "Asignada":
            current_time += timedelta(hours=random.randint(1, 24))
            history.append(make_status_change("Creada", "Asignada", gerente, current_time))
            task["assignedLeaderId"] = lider["id"]
            task["assignedLeaderName"] = lider["name"]
            task["assignedLeaderEmail"] = lider["email"]
            task["assignedToId"] = colaborador["id"]
            task["assignedToName"] = colaborador["name"]
            task["assignedToEmail"] = colaborador["email"]
            current_time += timedelta(hours=random.randint(4, 96))
            history.append(make_status_change("Asignada", "Cancelada", gerente, current_time, "Cancelada - ya no aplica"))

        else:  # Completa - Por Validar
            current_time += timedelta(hours=random.randint(1, 24))
            history.append(make_status_change("Creada", "Asignada", gerente, current_time))
            task["assignedLeaderId"] = lider["id"]
            task["assignedLeaderName"] = lider["name"]
            task["assignedLeaderEmail"] = lider["email"]
            task["assignedToId"] = colaborador["id"]
            task["assignedToName"] = colaborador["name"]
            task["assignedToEmail"] = colaborador["email"]
            current_time += timedelta(hours=random.randint(4, 48))
            history.append(make_status_change("Asignada", "Completa - Por Validar", colaborador, current_time))
            current_time += timedelta(hours=random.randint(2, 48))
            history.append(make_status_change("Completa - Por Validar", "Cancelada", gerente, current_time, "Cancelada por duplicidad"))

    task["statusHistory"] = history
    task["updatedAt"] = current_time if history else created_at
    task["updatedBy"] = history[-1]["changedByEmail"] if history else gerente["email"]

    # Para tareas "Asignada" - determinar si están en curso a tiempo o tarde
    if status == "Asignada":
        if NOW > due_date:
            # Está tarde (vencida)
            task["description"] += " [VENCIDA - requiere atención urgente]"

    return task


# ============================================
# GENERAR TAREAS
# ============================================
print(f"\n=== Generando {TOTAL_TAREAS} tareas ===")

# Limpiar tareas existentes
deleted = db.TaskItems.delete_many({})
print(f"Tareas anteriores eliminadas: {deleted.deleted_count}")

tareas = []
index = 1

for status, count in DISTRIBUCION.items():
    print(f"  Generando {count} tareas con estado '{status}'...")
    for _ in range(count):
        task = generate_task(status, index)
        tareas.append(task)
        index += 1

# Mezclar para que no estén ordenadas por estado
random.shuffle(tareas)

# Insertar en MongoDB
result = db.TaskItems.insert_many(tareas)
print(f"\n=== Tareas insertadas: {len(result.inserted_ids)} ===")

# ============================================
# RESUMEN ESTADÍSTICO
# ============================================
print("\n=== Resumen de tareas generadas ===")
pipeline = [
    {"$group": {"_id": "$status", "count": {"$sum": 1}}},
    {"$sort": {"_id": 1}},
]
for doc in db.TaskItems.aggregate(pipeline):
    print(f"  {doc['_id']}: {doc['count']}")

# Tareas completadas a tiempo vs tarde
completadas = list(db.TaskItems.find({"status": "Completa"}))
a_tiempo = 0
tarde = 0
for t in completadas:
    if t.get("dueDate") and t.get("statusHistory"):
        completion_dates = [
            h["changedAt"]
            for h in t["statusHistory"]
            if h["toStatus"] == "Completa - Por Validar"
        ]
        if completion_dates:
            completed_at = completion_dates[-1]
            if completed_at <= t["dueDate"]:
                a_tiempo += 1
            else:
                tarde += 1

print(f"\n  Completadas a tiempo: {a_tiempo}")
print(f"  Completadas tarde: {tarde}")

# Tareas en curso (Asignada) vencidas vs vigentes
asignadas = list(db.TaskItems.find({"status": "Asignada"}))
en_curso_ok = sum(1 for t in asignadas if t.get("dueDate") and t["dueDate"] >= NOW)
en_curso_tarde = sum(1 for t in asignadas if t.get("dueDate") and t["dueDate"] < NOW)
print(f"\n  En curso a tiempo: {en_curso_ok}")
print(f"  En curso vencidas: {en_curso_tarde}")

# Por colaborador
print("\n  Tareas por colaborador (asignado):")
pipeline_colab = [
    {"$match": {"assignedToName": {"$ne": None}}},
    {"$group": {"_id": "$assignedToName", "count": {"$sum": 1}}},
    {"$sort": {"count": -1}},
]
for doc in db.TaskItems.aggregate(pipeline_colab):
    print(f"    {doc['_id']}: {doc['count']}")

# Por líder
print("\n  Tareas por líder:")
pipeline_lider = [
    {"$match": {"assignedLeaderName": {"$ne": None}}},
    {"$group": {"_id": "$assignedLeaderName", "count": {"$sum": 1}}},
    {"$sort": {"count": -1}},
]
for doc in db.TaskItems.aggregate(pipeline_lider):
    print(f"    {doc['_id']}: {doc['count']}")

print("\n=== Script completado exitosamente ===")
client.close()
