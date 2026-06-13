// Migracion idempotente: asigna el campo `modules` a los roles existentes por nombre.
// Seguro de re-ejecutar: solo hace $set del array de modulos segun la matriz del contrato.
// NO crea roles nuevos ni borra datos. Roles no contemplados quedan intactos.
//
// Uso (ejemplo):
//   mongosh "mongodb://<host>:27017/bsc_db" seeds/migrate_roles_modules.js
//   docker exec -i bsc_mongo mongosh bsc_db < seeds/migrate_roles_modules.js

db = db.getSiblingDB('bsc_db');

// Matriz nombre de rol -> modulos (contrato compartido con el frontend).
const matrix = {
  'Administrador': ['roles', 'colaboradores', 'tareas', 'alertas-payroll'],
  'Gerente':       ['dashboard', 'tareas', 'alertas-payroll'],
  'Lider':         ['dashboard', 'tareas', 'alertas-payroll'],
  'Colaborador':   ['dashboard', 'tareas', 'alertas-payroll']
};

const now = new Date();
let updated = 0;
let notFound = [];

Object.keys(matrix).forEach(roleName => {
  const result = db.Roles.updateMany(
    { name: roleName },
    {
      $set: {
        modules: matrix[roleName],
        updatedAt: now,
        updatedBy: 'migrate_roles_modules'
      }
    }
  );

  if (result.matchedCount === 0) {
    notFound.push(roleName);
    print('Rol no encontrado (sin cambios): ' + roleName);
  } else {
    updated += result.modifiedCount;
    print('Rol actualizado: ' + roleName + ' -> [' + matrix[roleName].join(', ') + ']'
      + ' (matched=' + result.matchedCount + ', modified=' + result.modifiedCount + ')');
  }
});

print('--- Migracion de modulos completada ---');
print('Documentos modificados: ' + updated);
if (notFound.length > 0) {
  print('Roles no encontrados en BD: ' + notFound.join(', '));
}
