// ============================================
// BSC BackOffice - Seed de 100 Tareas Aleatorias
// ============================================
// Ejecutar dentro del contenedor MongoDB:
//   docker exec bsc_mongo bash -c 'mongosh "mongodb://bsc_admin:bsc_pass_2024@localhost:27017/bsc_db?authSource=admin" /seeds/seed_100_tareas.js'
//
// Prerequisito: haber ejecutado seed_prueba.js primero
// ============================================

print("=== Generando 100 tareas aleatorias ===");

// Obtener lideres y colaboradores existentes
var lideres = db.Colaboradores.find({
  IsDeleted: false,
  RolIds: db.Roles.findOne({name: "Lider"})._id.toString()
}).toArray();

var colaboradores = db.Colaboradores.find({
  IsDeleted: false,
  RolIds: db.Roles.findOne({name: "Colaborador"})._id.toString()
}).toArray();

var gerente = db.Colaboradores.findOne({
  IsDeleted: false,
  RolIds: db.Roles.findOne({name: "Gerente"})._id.toString()
});

print("  Gerente: " + gerente.NombreCompleto);
print("  Lideres encontrados: " + lideres.length);
print("  Colaboradores encontrados: " + colaboradores.length);

// Estados del frontend (STATUS_BADGE_MAP en Tasks.jsx)
var estados = [
  "Creada",
  "Asignada",
  "Completa - Por Validar",
  "Reasignada",
  "Completa - Validada",
  "Completa",
  "Cancelada"
];

// Titulos de tareas realistas por categoria
var tareasPorCategoria = {
  "Operaciones": [
    "Revision de inventario mensual",
    "Actualizacion de precios en sistema POS",
    "Auditoria de caja chica",
    "Verificacion de stock en bodega",
    "Control de calidad de productos recibidos",
    "Limpieza y organizacion de almacen",
    "Revision de equipos de refrigeracion",
    "Conteo fisico de mercaderia",
    "Validacion de ordenes de compra pendientes",
    "Reporte de mermas del mes",
    "Inspeccion de condiciones sanitarias",
    "Calibracion de balanzas",
    "Revision de fechas de caducidad",
    "Inventario de suministros de limpieza",
    "Control de temperatura de camaras frias"
  ],
  "Tecnologia": [
    "Actualizacion de firmware en terminales POS",
    "Respaldo de base de datos semanal",
    "Revision de logs del servidor",
    "Configuracion de nuevo punto de red",
    "Instalacion de actualizaciones de seguridad",
    "Mantenimiento preventivo de equipos",
    "Migracion de datos al nuevo sistema",
    "Correccion de error en modulo de reportes",
    "Optimizacion de consultas lentas en BD",
    "Configuracion de impresora termica",
    "Revision de certificados SSL",
    "Actualizacion de antivirus en estaciones",
    "Pruebas de rendimiento del sistema",
    "Documentacion de API interna",
    "Configuracion de VPN para sucursal"
  ],
  "Calidad": [
    "Auditoria interna de procesos",
    "Revision de cumplimiento de normas ISO",
    "Elaboracion de informe de satisfaccion al cliente",
    "Capacitacion en protocolos de calidad",
    "Revision de procedimientos operativos",
    "Analisis de quejas y reclamos del mes",
    "Actualizacion de manual de calidad",
    "Seguimiento de acciones correctivas",
    "Evaluacion de proveedores",
    "Inspeccion de puntos de venta",
    "Revision de indicadores KPI",
    "Elaboracion de plan de mejora continua",
    "Verificacion de registros de trazabilidad",
    "Encuesta de clima laboral",
    "Revision de politicas de devolucion"
  ],
  "Proyectos": [
    "Planificacion de apertura nueva sucursal",
    "Seguimiento de cronograma de implementacion",
    "Elaboracion de presupuesto trimestral",
    "Coordinacion con proveedores de equipamiento",
    "Revision de avance de obra civil",
    "Gestion de permisos municipales",
    "Diseno de layout de nueva tienda",
    "Evaluacion de propuestas de remodelacion",
    "Informe de factibilidad tecnica",
    "Coordinacion de mudanza de oficinas",
    "Seguimiento de contrato con constructora",
    "Elaboracion de plan de contingencia",
    "Revision de planos arquitectonicos",
    "Gestion de compras de mobiliario",
    "Informe de cierre de proyecto Q1"
  ]
};

var areas = Object.keys(tareasPorCategoria);

// Descripciones genericas para complementar
var descripciones = [
  "Tarea prioritaria que debe completarse dentro del plazo establecido.",
  "Realizar las verificaciones correspondientes y documentar hallazgos.",
  "Coordinar con el equipo asignado para asegurar el cumplimiento.",
  "Seguir el procedimiento estandar y reportar cualquier novedad.",
  "Completar la actividad segun los lineamientos del area.",
  "Revisar la documentacion previa antes de iniciar la ejecucion.",
  "Asegurar que se cumplan los criterios de calidad establecidos.",
  "Recopilar la informacion necesaria y generar el entregable.",
  "Validar con el lider antes de cerrar la actividad.",
  "Documentar el proceso y adjuntar evidencias al finalizar."
];

var observacionesReasignadas = [
  "Revisar los puntos observados y corregir.",
  "Se necesita mas detalle en el entregable.",
  "Falta completar la documentacion de soporte.",
  "La evidencia adjunta no es suficiente.",
  "Hay inconsistencias en el informe entregado."
];

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomElement(arr) {
  return arr[randomInt(0, arr.length - 1)];
}

function randomDate(startDays, endDays) {
  var now = new Date();
  var offset = randomInt(startDays, endDays);
  return new Date(now.getTime() + offset * 24 * 60 * 60 * 1000);
}

function getLiderByArea(area) {
  var areaLideres = lideres.filter(function(l) { return l.Area === area; });
  if (areaLideres.length > 0) return randomElement(areaLideres);
  return randomElement(lideres);
}

function getColaboradorByArea(area) {
  var areaColabs = colaboradores.filter(function(c) { return c.Area === area; });
  if (areaColabs.length > 0) return randomElement(areaColabs);
  return randomElement(colaboradores);
}

// Limpiar tareas existentes
db.TaskItems.drop();
print("  Coleccion TaskItems limpiada");

var tareas = [];

for (var i = 0; i < 100; i++) {
  var area = randomElement(areas);
  var tareasArea = tareasPorCategoria[area];
  var titulo = randomElement(tareasArea);
  // Agregar sufijo para evitar duplicados exactos
  var sufijo = " #" + (i + 1).toString().padStart(3, "0");

  var estado = randomElement(estados);
  var lider = getLiderByArea(area);
  var colaborador = getColaboradorByArea(area);

  var createdAt = randomDate(-30, -5); // creada entre 30 y 5 dias atras
  var dueDate = randomDate(1, 30);     // vence entre 1 y 30 dias adelante
  var estimatedTime = randomInt(1, 40); // 1 a 40 horas

  var tarea = {
    title: titulo + sufijo,
    description: randomElement(descripciones),
    status: estado,
    assignedLeaderId: null,
    assignedLeaderName: null,
    assignedLeaderEmail: null,
    assignedToId: null,
    assignedToName: null,
    assignedToEmail: null,
    dueDate: dueDate,
    estimatedTime: NumberDecimal(estimatedTime.toString()),
    actualTime: null,
    insumos: null,
    insumoFiles: [],
    evidenceFiles: [],
    evidenceText: null,
    observations: null,
    statusHistory: [],
    createdAt: createdAt,
    createdBy: gerente._id.toString(),
    updatedAt: createdAt,
    updatedBy: gerente._id.toString(),
    isDeleted: false,
    deletedAt: null
  };

  // Construir historial segun el estado
  // Flujo: Creada -> Asignada -> Completa - Por Validar -> Completa - Validada -> Completa
  // Alternativas: Reasignada (devuelta), Cancelada
  var historyTime = new Date(createdAt.getTime());

  // Todas las tareas inician como Creada
  tarea.statusHistory.push({
    fromStatus: "",
    toStatus: "Creada",
    changedById: gerente._id.toString(),
    changedByName: gerente.NombreCompleto,
    changedByEmail: gerente.Correo,
    changedAt: historyTime,
    comment: "Tarea creada"
  });

  // Asignada: gerente asigna lider y colaborador
  if (estado !== "Creada") {
    tarea.assignedLeaderId = lider._id.toString();
    tarea.assignedLeaderName = lider.NombreCompleto;
    tarea.assignedLeaderEmail = lider.Correo;
    tarea.assignedToId = colaborador._id.toString();
    tarea.assignedToName = colaborador.NombreCompleto;
    tarea.assignedToEmail = colaborador.Correo;

    historyTime = new Date(historyTime.getTime() + randomInt(1, 24) * 3600000);
    tarea.statusHistory.push({
      fromStatus: "Creada",
      toStatus: "Asignada",
      changedById: gerente._id.toString(),
      changedByName: gerente.NombreCompleto,
      changedByEmail: gerente.Correo,
      changedAt: historyTime,
      comment: "Asignada a " + colaborador.NombreCompleto + " (Lider: " + lider.NombreCompleto + ")"
    });
    tarea.updatedAt = historyTime;
  }

  // Completa - Por Validar: colaborador marca como completada
  if (["Completa - Por Validar", "Completa - Validada", "Completa", "Reasignada"].indexOf(estado) >= 0) {
    tarea.actualTime = NumberDecimal(randomInt(Math.max(1, estimatedTime - 10), estimatedTime + 10).toString());
    tarea.evidenceText = "Tarea completada. Se adjuntan evidencias del trabajo realizado.";

    historyTime = new Date(historyTime.getTime() + randomInt(12, 72) * 3600000);
    tarea.statusHistory.push({
      fromStatus: "Asignada",
      toStatus: "Completa - Por Validar",
      changedById: colaborador._id.toString(),
      changedByName: colaborador.NombreCompleto,
      changedByEmail: colaborador.Correo,
      changedAt: historyTime,
      comment: "Trabajo finalizado, evidencias adjuntas"
    });
    tarea.updatedAt = historyTime;
  }

  // Reasignada: lider devuelve la tarea
  if (estado === "Reasignada") {
    tarea.observations = randomElement(observacionesReasignadas);
    historyTime = new Date(historyTime.getTime() + randomInt(1, 24) * 3600000);
    tarea.statusHistory.push({
      fromStatus: "Completa - Por Validar",
      toStatus: "Reasignada",
      changedById: lider._id.toString(),
      changedByName: lider.NombreCompleto,
      changedByEmail: lider.Correo,
      changedAt: historyTime,
      comment: tarea.observations
    });
    tarea.updatedAt = historyTime;
  }

  // Completa - Validada: lider valida la tarea
  if (["Completa - Validada", "Completa"].indexOf(estado) >= 0) {
    historyTime = new Date(historyTime.getTime() + randomInt(1, 24) * 3600000);
    tarea.statusHistory.push({
      fromStatus: "Completa - Por Validar",
      toStatus: "Completa - Validada",
      changedById: lider._id.toString(),
      changedByName: lider.NombreCompleto,
      changedByEmail: lider.Correo,
      changedAt: historyTime,
      comment: "Validacion correcta, cumple los criterios"
    });
    tarea.updatedAt = historyTime;
  }

  // Completa: gerente da aprobacion final
  if (estado === "Completa") {
    historyTime = new Date(historyTime.getTime() + randomInt(1, 24) * 3600000);
    tarea.statusHistory.push({
      fromStatus: "Completa - Validada",
      toStatus: "Completa",
      changedById: gerente._id.toString(),
      changedByName: gerente.NombreCompleto,
      changedByEmail: gerente.Correo,
      changedAt: historyTime,
      comment: "Aprobada por gerencia"
    });
    tarea.updatedAt = historyTime;
  }

  // Cancelada: gerente cancela la tarea
  if (estado === "Cancelada") {
    tarea.assignedLeaderId = lider._id.toString();
    tarea.assignedLeaderName = lider.NombreCompleto;
    tarea.assignedLeaderEmail = lider.Correo;
    tarea.assignedToId = colaborador._id.toString();
    tarea.assignedToName = colaborador.NombreCompleto;
    tarea.assignedToEmail = colaborador.Correo;

    // Algunas canceladas pasaron por Asignada primero
    historyTime = new Date(historyTime.getTime() + randomInt(1, 24) * 3600000);
    tarea.statusHistory.push({
      fromStatus: "Creada",
      toStatus: "Asignada",
      changedById: gerente._id.toString(),
      changedByName: gerente.NombreCompleto,
      changedByEmail: gerente.Correo,
      changedAt: historyTime,
      comment: "Asignada a " + colaborador.NombreCompleto
    });

    historyTime = new Date(historyTime.getTime() + randomInt(1, 48) * 3600000);
    tarea.statusHistory.push({
      fromStatus: "Asignada",
      toStatus: "Cancelada",
      changedById: gerente._id.toString(),
      changedByName: gerente.NombreCompleto,
      changedByEmail: gerente.Correo,
      changedAt: historyTime,
      comment: "Tarea cancelada por gerencia"
    });
    tarea.updatedAt = historyTime;
  }

  tareas.push(tarea);
}

db.TaskItems.insertMany(tareas);

// Resumen por estado
print("");
print("=== 100 Tareas creadas ===");
print("");
estados.forEach(function(e) {
  var count = db.TaskItems.countDocuments({status: e});
  if (count > 0) print("  " + e + ": " + count);
});
print("");
print("  Total: " + db.TaskItems.countDocuments());
print("");

// Resumen por area (basado en lider asignado)
print("=== Distribucion por lider ===");
db.TaskItems.aggregate([
  {$match: {assignedLeaderName: {$ne: null}}},
  {$group: {_id: "$assignedLeaderName", count: {$sum: 1}}},
  {$sort: {count: -1}}
]).forEach(function(r) {
  print("  " + r._id + ": " + r.count + " tareas");
});
print("");

print("=== Distribucion por colaborador ===");
db.TaskItems.aggregate([
  {$match: {assignedToName: {$ne: null}}},
  {$group: {_id: "$assignedToName", count: {$sum: 1}}},
  {$sort: {count: -1}}
]).forEach(function(r) {
  print("  " + r._id + ": " + r.count + " tareas");
});
