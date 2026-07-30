#!/bin/bash
# ============================================================================
# consultar-tareas-prod.sh
#
# Consulta ad-hoc de la coleccion TaskItems (modulo Tareas) en la base Mongo
# de PRODUCCION (cx@192.168.100.9), de solo lectura. Uso tipico: "¿quien
# creo/cargo esta tarea?", "¿que tareas tiene asignadas Fulano con esa fecha
# de entrega?", etc.
#
# USO:
#   ./scripts/consultar-tareas-prod.sh "texto a buscar"
#
#   Busca (case-insensitive) el texto en los campos `title` Y `description`
#   de TaskItems y muestra: title, description, status, createdBy, createdAt,
#   assignedLeaderName, assignedToName, dueDate, _id.
#
# EJEMPLOS:
#   ./scripts/consultar-tareas-prod.sh "flujo de caja"
#   ./scripts/consultar-tareas-prod.sh "valores preliminares"
#
# La contrasena SSH del servidor (usuario cx) se pide en el momento (no se
# guarda en ningun archivo ni variable de entorno persistente). Requiere
# tener `sshpass` instalado (en este equipo: via winget, ya disponible en
# Git Bash) y el password de git bash's ssh no necesita tty extra.
#
# COMO FUNCIONA (por si hay que adaptarlo):
#   `ssh -p` interactivo directo con sshpass falla en este entorno con
#   "read_passphrase: can't open /dev/tty" — el cliente OpenSSH moderno
#   intenta abrir /dev/tty en vez de leer el prompt que sshpass intercepta.
#   El workaround es usar el mecanismo SSH_ASKPASS: se crea un script
#   temporal que solo hace `echo "$password"`, se apunta SSH_ASKPASS a ese
#   script y se fuerza SSH_ASKPASS_REQUIRE=force + stdin desde /dev/null
#   (sin eso, ssh igual intenta /dev/tty primero). El script temporal se
#   borra automaticamente al salir (trap).
#
#   Para consultar OTRA coleccion (ej. Colaboradores, Roles) o cambiar los
#   campos que se muestran, edita el `db.TaskItems.find(...)` mas abajo.
# ============================================================================

set -euo pipefail

SEARCH_TERM="${1:-}"
if [ -z "$SEARCH_TERM" ]; then
  echo "Uso: $0 \"texto a buscar en titulo o descripcion\""
  exit 1
fi

SSH_HOST="cx@192.168.100.9"
REMOTE_DIR="~/BSC"

TMPDIR="$(mktemp -d)"
ASKPASS_SCRIPT="$TMPDIR/askpass.sh"
REMOTE_SCRIPT="$TMPDIR/query.sh"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

read -r -s -p "Password SSH de $SSH_HOST: " SSH_PASSWORD
echo

cat > "$ASKPASS_SCRIPT" <<EOF
#!/bin/sh
echo '$SSH_PASSWORD'
EOF
chmod +x "$ASKPASS_SCRIPT"

# El termino de busqueda se pasa embebido en el eval de mongosh; se escapan
# comillas simples por si el termino las trae.
ESCAPED_TERM=$(printf '%s' "$SEARCH_TERM" | sed "s/'/\\\\'/g")

cat > "$REMOTE_SCRIPT" <<EOF
#!/bin/bash
set -e
cd $REMOTE_DIR
docker exec bsc_mongo sh -c 'mongosh --quiet -u "\$MONGO_INITDB_ROOT_USERNAME" -p "\$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin bsc_db --eval "
var re = /$ESCAPED_TERM/i;
var found = 0;
db.TaskItems.find({\\\$or:[{title:re},{description:re}]}).forEach(function(t){
  found++;
  printjson({
    id: t._id,
    title: t.title,
    description: t.description,
    status: t.status,
    createdBy: t.createdBy,
    createdAt: t.createdAt,
    assignedLeaderName: t.assignedLeaderName,
    assignedToName: t.assignedToName,
    dueDate: t.dueDate
  });
});
if (found === 0) print(\"(sin coincidencias)\");
"'
EOF

export SSH_ASKPASS="$ASKPASS_SCRIPT"
export SSH_ASKPASS_REQUIRE=force

B64=$(base64 -w0 "$REMOTE_SCRIPT")
ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password "$SSH_HOST" \
  "echo $B64 | base64 -d | bash" < /dev/null
