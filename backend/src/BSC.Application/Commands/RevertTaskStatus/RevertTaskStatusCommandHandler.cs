using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.RevertTaskStatus;

/// <summary>
/// Handler para el comando de reversion de estado de tarea.
/// Lee el historial y revierte al estado anterior, registrando el movimiento.
/// </summary>
public class RevertTaskStatusCommandHandler : IRequestHandler<RevertTaskStatusCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly IColaboradorRepository _colaboradorRepository;
    private readonly ILogger<RevertTaskStatusCommandHandler> _logger;

    public RevertTaskStatusCommandHandler(
        ITaskItemRepository taskItemRepository,
        IColaboradorRepository colaboradorRepository,
        ILogger<RevertTaskStatusCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _colaboradorRepository = colaboradorRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(RevertTaskStatusCommand request, CancellationToken cancellationToken)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(request.TaskId);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{request.TaskId}'." }
            );
        }

        // Solo Lider y Colaborador pueden retomar
        if (request.RevertedByRole != TaskStateTransitions.RolLider &&
            request.RevertedByRole != TaskStateTransitions.RolColaborador)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Accion no permitida.",
                new List<string> { "Solo Lider y Colaborador pueden retomar tareas." }
            );
        }

        // Verificar que hay historial para revertir
        if (taskItem.StatusHistory == null || !taskItem.StatusHistory.Any())
        {
            return ApiResponse<TaskItemDto>.Fail(
                "No se puede retomar.",
                new List<string> { "La tarea no tiene historial de estados para revertir." }
            );
        }

        // Obtener el ultimo movimiento del historial
        var lastChange = taskItem.StatusHistory
            .OrderByDescending(h => h.ChangedAt)
            .First();

        var previousStatus = lastChange.FromStatus;

        // Validar que el estado anterior es un estado valido
        if (!TaskStatuses.IsValid(previousStatus))
        {
            return ApiResponse<TaskItemDto>.Fail(
                "No se puede retomar.",
                new List<string> { $"El estado anterior '{previousStatus}' no es un estado valido." }
            );
        }

        // Validar que la tarea esta asignada al usuario que intenta retomar
        if (request.RevertedByRole == TaskStateTransitions.RolColaborador &&
            !string.Equals(taskItem.AssignedToEmail, request.RevertedByEmail, StringComparison.OrdinalIgnoreCase))
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Accion no permitida.",
                new List<string> { "Solo el colaborador asignado puede retomar esta tarea." }
            );
        }

        if (request.RevertedByRole == TaskStateTransitions.RolLider &&
            !string.Equals(taskItem.AssignedLeaderEmail, request.RevertedByEmail, StringComparison.OrdinalIgnoreCase))
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Accion no permitida.",
                new List<string> { "Solo el lider asignado puede retomar esta tarea." }
            );
        }

        // Buscar datos del usuario que realiza la reversion
        var revertedBy = await _colaboradorRepository.GetByCorreoAsync(request.RevertedByEmail);
        var revertedByName = revertedBy?.NombreCompleto ?? request.RevertedByEmail;
        var revertedById = revertedBy?.Id ?? string.Empty;

        var currentStatus = taskItem.Status;

        // Agregar entrada al historial registrando la reversion
        taskItem.StatusHistory.Add(new StatusChange
        {
            FromStatus = currentStatus,
            ToStatus = previousStatus,
            ChangedById = revertedById,
            ChangedByName = revertedByName,
            ChangedByEmail = request.RevertedByEmail,
            ChangedAt = DateTime.UtcNow,
            Comment = request.Comment ?? "Tarea retomada"
        });

        taskItem.Status = previousStatus;
        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.RevertedByEmail;

        await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation(
            "Tarea retomada: {TaskId} de '{FromStatus}' a '{ToStatus}' por {Email} ({Role})",
            taskItem.Id, currentStatus, previousStatus, request.RevertedByEmail, request.RevertedByRole);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(taskItem), "Tarea retomada exitosamente.");
    }
}
