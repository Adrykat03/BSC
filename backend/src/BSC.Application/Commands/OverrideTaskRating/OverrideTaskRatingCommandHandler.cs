using BSC.Application.DTOs;
using BSC.Application.Mappings;
using BSC.Domain.Constants;
using BSC.Domain.Interfaces;
using BSC.Domain.ValueObjects;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.OverrideTaskRating;

/// <summary>
/// Handler que aplica un override manual de calificación.
/// Solo Gerente puede ejecutarlo y solo sobre tareas en estado "Completa - Validada" o "Completa".
/// Registra una entrada append-only en RatingHistory y sincroniza el campo Rating.
/// </summary>
public class OverrideTaskRatingCommandHandler
    : IRequestHandler<OverrideTaskRatingCommand, ApiResponse<TaskItemDto>>
{
    private static readonly HashSet<string> AllowedStatuses = new(StringComparer.OrdinalIgnoreCase)
    {
        TaskStatuses.CompletaValidada,
        TaskStatuses.Completa,
    };

    private readonly ITaskItemRepository _taskItemRepository;
    private readonly IColaboradorRepository _colaboradorRepository;
    private readonly ILogger<OverrideTaskRatingCommandHandler> _logger;

    public OverrideTaskRatingCommandHandler(
        ITaskItemRepository taskItemRepository,
        IColaboradorRepository colaboradorRepository,
        ILogger<OverrideTaskRatingCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _colaboradorRepository = colaboradorRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(
        OverrideTaskRatingCommand request,
        CancellationToken cancellationToken)
    {
        var task = await _taskItemRepository.GetByIdAsync(request.TaskId);
        if (task == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontró una tarea con el ID '{request.TaskId}'." }
            );
        }

        if (request.ChangedByRole != TaskStateTransitions.RolGerente)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Operación no permitida.",
                new List<string> { "Solo el rol Gerente puede modificar la calificación." }
            );
        }

        if (!AllowedStatuses.Contains(task.Status))
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Estado no permite modificar la calificación.",
                new List<string>
                {
                    $"La tarea está en estado '{task.Status}'.",
                    $"Solo se puede modificar la calificación en '{TaskStatuses.CompletaValidada}' o '{TaskStatuses.Completa}'."
                }
            );
        }

        var changedBy = await _colaboradorRepository.GetByCorreoAsync(request.ChangedByEmail);
        var changedByName = changedBy?.NombreCompleto ?? request.ChangedByEmail;
        var changedById = changedBy?.Id ?? string.Empty;

        var previousRating = task.Rating;
        var now = DateTime.UtcNow;

        task.RatingHistory.Add(new RatingChange
        {
            FromRating = previousRating,
            ToRating = request.NewRating,
            ChangedById = changedById,
            ChangedByName = changedByName,
            ChangedByEmail = request.ChangedByEmail,
            ChangedAt = now,
            Reason = request.Reason.Trim(),
        });

        task.Rating = request.NewRating;
        task.RatingOverride = request.NewRating;
        task.RatingOverrideReason = request.Reason.Trim();
        task.RatingOverrideBy = request.ChangedByEmail;
        task.RatingOverrideAt = now;
        task.UpdatedAt = now;
        task.UpdatedBy = request.ChangedByEmail;

        await _taskItemRepository.UpdateAsync(task);

        _logger.LogInformation(
            "Override de calificación: tarea {TaskId} de {From} a {To} por {Email}.",
            task.Id, previousRating, request.NewRating, request.ChangedByEmail);

        return ApiResponse<TaskItemDto>.Ok(
            TaskItemMapper.ToDto(task),
            "Calificación actualizada exitosamente."
        );
    }
}
