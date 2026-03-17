using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Queries.GetTaskItemById;

/// <summary>
/// Handler para la query de obtener tarea por ID.
/// </summary>
public class GetTaskItemByIdQueryHandler : IRequestHandler<GetTaskItemByIdQuery, ApiResponse<TaskItemDto>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<GetTaskItemByIdQueryHandler> _logger;

    public GetTaskItemByIdQueryHandler(ITaskItemRepository taskItemRepository, ILogger<GetTaskItemByIdQueryHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<TaskItemDto>> Handle(GetTaskItemByIdQuery request, CancellationToken cancellationToken)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(request.Id);
        if (taskItem == null)
        {
            return ApiResponse<TaskItemDto>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontró una tarea con el ID '{request.Id}'." }
            );
        }

        var dto = new TaskItemDto
        {
            Id = taskItem.Id,
            Title = taskItem.Title,
            Description = taskItem.Description,
            AssignedTo = taskItem.AssignedTo,
            Status = taskItem.Status,
            EstimatedTime = taskItem.EstimatedTime,
            ActualTime = taskItem.ActualTime,
            EvidenceFileName = taskItem.EvidenceFileName,
            HasEvidence = !string.IsNullOrEmpty(taskItem.EvidenceFilePath),
            CreatedAt = taskItem.CreatedAt,
            UpdatedAt = taskItem.UpdatedAt
        };

        return ApiResponse<TaskItemDto>.Ok(dto);
    }
}
