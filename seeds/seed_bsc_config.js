// Seed: Crear configuracion BSC Dashboard
// Ejecutar con: mongosh mongodb://bsc_admin:bsc_pass_2024@localhost:27017/bsc_db?authSource=admin seeds/seed_bsc_config.js

db = db.getSiblingDB('bsc_db');

const now = new Date();

// Verificar si ya existe una config activa
const existing = db.BscDashboardConfigs.findOne({ isActive: true });
if (existing) {
  print('Config BSC ya existe (ID: ' + existing._id + ')');
  print('Emails: ' + JSON.stringify(existing.emails));
  print('Patron: ' + existing.taskTitlePattern);
} else {
  db.BscDashboardConfigs.insertOne({
    emails: [
      'isabella.sanchez@kfc.com.ec',
      'manuel.zapata@kfc.com.ec'
    ],
    taskTitlePattern: 'Proceso mensual liquidaciones',
    isActive: true,
    createdAt: now,
    updatedAt: now
  });
  print('Config BSC creada exitosamente');
}

print('--- Seed BSC Config completado ---');
