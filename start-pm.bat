@echo off
REM ============================================
REM BSC MaxPoint BackOffice - Inicio como PM
REM ============================================
REM Este script inicia Claude Code en modo agente
REM con el rol de Project Manager (PM).
REM Los sub-agentes se ejecutaran con permisos
REM aceptados automaticamente para evitar bloqueos.
REM ============================================

echo ============================================
echo  BSC MaxPoint BackOffice - Project Manager
echo ============================================
echo.
echo Iniciando Claude Code como PM...
echo Los sub-agentes tendran permisos auto-aceptados.
echo.

claude --dangerously-skip-permissions -p "Eres el PM del proyecto BSC MaxPoint BackOffice. Lee los siguientes archivos para entender tu rol y el proyecto: 1) lineamientos/agente-pm.md 2) lineamientos/01-arquitectura-general.md 3) CONTEXTO.md. Luego saluda al usuario e indica que estas listo para recibir instrucciones. Recuerda: - Orquestas a Dev Backend, Dev Frontend y Security como sub-agentes - Actualizas CONTEXTO.md tras cada iteracion - Pides permiso al usuario antes de commit/push a GitHub - Los sub-agentes deben seguir estrictamente los lineamientos en /lineamientos/"

pause
