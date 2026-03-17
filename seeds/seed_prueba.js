// ============================================
// BSC BackOffice - Seed de Prueba
// ============================================
// Ejecutar dentro del contenedor MongoDB:
//   docker exec bsc_mongo mongosh "mongodb://bsc_admin:bsc_pass_2024@localhost:27017/bsc_db?authSource=admin" /seeds/seed_prueba.js
//
// Password de todos los usuarios: Test1234!
// ============================================

print("=== Limpiando base de datos ===");
db.Roles.drop();
db.Colaboradores.drop();
db.TaskItems.drop();

// ============================================
// ROLES
// ============================================
print("=== Insertando Roles ===");
db.Roles.insertMany([
  {
    name: "Gerente",
    description: "Responsable de crear tareas, asignar a lideres y dar aprobacion final",
    createdAt: new Date(),
    updatedAt: new Date(),
    createdBy: "system",
    updatedBy: "system",
    isDeleted: false,
    deletedAt: null
  },
  {
    name: "Lider",
    description: "Valida tareas completadas, asigna a colaboradores y supervisa la ejecucion",
    createdAt: new Date(),
    updatedAt: new Date(),
    createdBy: "system",
    updatedBy: "system",
    isDeleted: false,
    deletedAt: null
  },
  {
    name: "Colaborador",
    description: "Ejecuta las tareas asignadas, sube evidencias y reporta avance",
    createdAt: new Date(),
    updatedAt: new Date(),
    createdBy: "system",
    updatedBy: "system",
    isDeleted: false,
    deletedAt: null
  },
  {
    name: "Administrador",
    description: "Gestiona roles y colaboradores del sistema. No participa en tareas.",
    createdAt: new Date(),
    updatedAt: new Date(),
    createdBy: "system",
    updatedBy: "system",
    isDeleted: false,
    deletedAt: null
  }
]);

var gerenteRolId = db.Roles.findOne({name: "Gerente"})._id.toString();
var liderRolId = db.Roles.findOne({name: "Lider"})._id.toString();
var colaboradorRolId = db.Roles.findOne({name: "Colaborador"})._id.toString();
var adminRolId = db.Roles.findOne({name: "Administrador"})._id.toString();

print("  Gerente ID: " + gerenteRolId);
print("  Lider ID: " + liderRolId);
print("  Colaborador ID: " + colaboradorRolId);
print("  Administrador ID: " + adminRolId);

// ============================================
// COLABORADORES
// ============================================
print("=== Insertando Colaboradores ===");

// BCrypt hash para "Test1234!" (work factor 11)
var passHash = "$2a$11$a5hyF1ZDwKovUSJ3DVVjGeuWmpzpzldnGoz8gTa9J6vTY59hyF4o6";

function insertColaborador(nombre, cedula, area, correo, rolIds) {
  db.Colaboradores.insertOne({
    NombreCompleto: nombre,
    Cedula: cedula,
    Area: area,
    Correo: correo,
    PasswordHash: passHash,
    RolIds: rolIds,
    CreatedAt: new Date(),
    UpdatedAt: new Date(),
    IsDeleted: false,
    CreatedBy: "system",
    UpdatedBy: "system",
    DeletedAt: null
  });
}

// 1 Administrador (rol exclusivo)
insertColaborador("Maria Espinoza", "1700112233", "Sistemas", "maria.espinoza@bsc.com", [adminRolId]);

// 1 Gerente (rol exclusivo)
insertColaborador("Carlos Mendoza", "1712345678", "Direccion General", "carlos.mendoza@bsc.com", [gerenteRolId]);

// 2 Lideres puros
insertColaborador("Ana Torres", "1723456789", "Tecnologia", "ana.torres@bsc.com", [liderRolId]);
insertColaborador("Marco Reyes", "1734567890", "Operaciones", "marco.reyes@bsc.com", [liderRolId]);

// 2 Lideres + Colaborador (multi-rol)
insertColaborador("Laura Vega", "1745678901", "Calidad", "laura.vega@bsc.com", [liderRolId, colaboradorRolId]);
insertColaborador("Diego Paredes", "1756789012", "Proyectos", "diego.paredes@bsc.com", [liderRolId, colaboradorRolId]);

// 10 Colaboradores
insertColaborador("Sofia Herrera", "1767890123", "Tecnologia", "sofia.herrera@bsc.com", [colaboradorRolId]);
insertColaborador("Andres Loor", "1778901234", "Tecnologia", "andres.loor@bsc.com", [colaboradorRolId]);
insertColaborador("Daniela Cruz", "1789012345", "Operaciones", "daniela.cruz@bsc.com", [colaboradorRolId]);
insertColaborador("Pablo Salazar", "1790123456", "Operaciones", "pablo.salazar@bsc.com", [colaboradorRolId]);
insertColaborador("Camila Flores", "1701234567", "Calidad", "camila.flores@bsc.com", [colaboradorRolId]);
insertColaborador("Ricardo Nunez", "1712340987", "Calidad", "ricardo.nunez@bsc.com", [colaboradorRolId]);
insertColaborador("Valeria Moran", "1723451098", "Proyectos", "valeria.moran@bsc.com", [colaboradorRolId]);
insertColaborador("Fernando Diaz", "1734562109", "Proyectos", "fernando.diaz@bsc.com", [colaboradorRolId]);
insertColaborador("Isabella Ponce", "1745673210", "Tecnologia", "isabella.ponce@bsc.com", [colaboradorRolId]);
insertColaborador("Sebastian Aguilar", "1756784321", "Operaciones", "sebastian.aguilar@bsc.com", [colaboradorRolId]);

// ============================================
// RESUMEN
// ============================================
print("");
print("=== Seed completado ===");
print("Roles: " + db.Roles.countDocuments());
print("Colaboradores: " + db.Colaboradores.countDocuments());
print("  - Administradores: " + db.Colaboradores.countDocuments({RolIds: adminRolId}));
print("  - Gerentes: " + db.Colaboradores.countDocuments({RolIds: gerenteRolId}));
print("  - Lideres: " + db.Colaboradores.countDocuments({RolIds: liderRolId}));
print("  - Colaboradores: " + db.Colaboradores.countDocuments({RolIds: colaboradorRolId}));
print("  - Multi-rol (Lider+Colaborador): " + db.Colaboradores.countDocuments({RolIds: {$all: [liderRolId, colaboradorRolId]}}));
print("");
print("Password de todos los usuarios: Test1234!");
print("");
print("=== Usuarios creados ===");
db.Colaboradores.find({}, {NombreCompleto: 1, Correo: 1, RolIds: 1}).forEach(function(c) {
  var rolNames = c.RolIds.map(function(rid) {
    var r = db.Roles.findOne({_id: ObjectId(rid)});
    return r ? r.name : "?";
  });
  print("  " + c.NombreCompleto + " | " + c.Correo + " | " + rolNames.join(", "));
});
