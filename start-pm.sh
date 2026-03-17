#!/bin/bash
# ============================================
# BSC BackOffice - Inicio como PM (Linux/tmux)
# ============================================
# Inicia una sesión tmux con Claude Code en
# modo interactivo con permisos auto-aceptados
# para sub-agentes.
# ============================================

SESSION_NAME="bsc-pm"

# Si ya existe la sesión, adjuntarse
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Sesión '$SESSION_NAME' ya existe, adjuntándose..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

echo "============================================"
echo " BSC BackOffice - Project Manager"
echo "============================================"
echo ""
echo "Iniciando sesión tmux '$SESSION_NAME'..."
echo ""

tmux new-session -d -s "$SESSION_NAME" -c "/home/lsalazar/Proyectos/BSC"
tmux send-keys -t "$SESSION_NAME" "claude --dangerously-skip-permissions" Enter
tmux attach-session -t "$SESSION_NAME"
