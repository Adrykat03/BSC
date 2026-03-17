using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.ChangeTaskStatus;

/// <summary>
/// Handler para el comando de cambio de estado de tarea.
/// Valida la transicion segun la matriz de permisos por rol.
/// </summary>
public class ChangeTaskStatusCommandHandler : IRequestHandler<ChangeTaskStatusCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly IColaboradorRepository _colaboradorRepository;
    private readonly ILogger<ChangeTaskStatusCommandHandler> _logger;

    public ChangeTaskStatusCommandHandler(
        ITaskItemRepository taskItemRepository,
        IColaboradorRepository colaboradorRepository,
        ILogger<ChangeTaskStatusCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _colaboradorRepository = colaboradorRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(ChangeTaskStatusCommand request, CancellationToken cancellationToken)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(request.TaskId);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{request.TaskId}'." }
            );
        }

        // Validar que el nuevo estado es valido
        if (!TaskStatuses.IsValid(request.NewStatus))
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Estado no valido.",
                new List<string> { $"El estado '{request.NewStatus}' no es un estado valido." }
            );
        }

        // Validar transicion segun rol
        if (!TaskStateTransitions.IsValidTransition(request.ChangedByRole, taskItem.Status, request.NewStatus))
        {
            var allowed = TaskStateTransitions.GetAllowedTransitions(request.ChangedByRole, taskItem.Status);
            var allowedStr = allowed.Any() ? string.Join(", ", allowed) : "ninguna";

            return ApiResponse<TaskItemDto>.Fail(
                "Transicion de estado no permitida.",
                new List<string>
                {
                    $"El rol '{request.ChangedByRole}' no puede cambiar de '{taskItem.Status}' a '{request.NewStatus}'.",
                    $"Transiciones permitidas desde '{taskItem.Status}': {allowedStr}."
                }
            );
        }

        // Buscar datos del colaborador que realiza el cambio
        var changedBy = await _colaboradorRepository.GetByCorreoAsync(request.ChangedByEmail);
        var changedByName = changedBy?.NombreCompleto ?? request.ChangedByEmail;
        var changedById = changedBy?.Id ?? string.Empty;

        var previousStatus = taskItem.Status;

        // Agregar entrada al historial de estados
        taskItem.StatusHistory.Add(new StatusChange
        {
            FromStatus = previousStatus,
            ToStatus = request.NewStatus,
            ChangedById = changedById,
            ChangedByName = changedByName,
            ChangedByEmail = request.ChangedByEmail,
            ChangedAt = DateTime.UtcNow,
            Comment = request.Comment
        });

        taskItem.Status = request.NewStatus;
        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.ChangedByEmail;

        await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation(
            "Estado de tarea cambiado: {TaskId} de '{FromStatus}' a '{ToStatus}' por {Email} ({Role})",
            taskItem.Id, previousStatus, request.NewStatus, request.ChangedByEmail, request.ChangedByRole);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(taskItem), "Estado actualizado exitosamente.");
    }
}
