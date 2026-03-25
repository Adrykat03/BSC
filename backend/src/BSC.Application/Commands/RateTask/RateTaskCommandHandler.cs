using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.RateTask;

/// <summary>
/// Handler para el comando de calificacion de tarea.
/// Solo Lider y Gerente pueden calificar (1-10).
/// </summary>
public class RateTaskCommandHandler : IRequestHandler<RateTaskCommand, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<RateTaskCommandHandler> _logger;

    public RateTaskCommandHandler(
        ITaskItemRepository taskItemRepository,
        ILogger<RateTaskCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(RateTaskCommand request, CancellationToken cancellationToken)
    {
        if (request.RatedByRole != "Lider" && request.RatedByRole != "Gerente")
        {
            return ApiResponse<TaskItemDto>.Fail(
                "No autorizado.",
                new List<string> { "Solo el Lider y el Gerente pueden calificar tareas." }
            );
        }

        if (request.Rating < 1 || request.Rating > 10)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Calificacion no valida.",
                new List<string> { "La calificacion debe ser un valor entre 1 y 10." }
            );
        }

        var taskItem = await _taskItemRepository.GetByIdAsync(request.TaskId);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontro una tarea con el ID '{request.TaskId}'." }
            );
        }

        taskItem.Rating = request.Rating;
        taskItem.UpdatedAt = DateTime.UtcNow;
        taskItem.UpdatedBy = request.RatedByEmail;

        await _taskItemRepository.UpdateAsync(taskItem);

        _logger.LogInformation(
            "Tarea calificada: {TaskId} con {Rating}/10 por {Email} ({Role})",
            taskItem.Id, request.Rating, request.RatedByEmail, request.RatedByRole);

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(taskItem), "Calificacion guardada exitosamente.");
    }
}
