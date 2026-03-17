using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Queries.GetTaskItems;

/// <summary>
/// Handler para la query de listado de tareas.
/// </summary>
public class GetTaskItemsQueryHandler : IRequestHandler<GetTaskItemsQuery, ApiResponse<PaginatedResult<TaskItemDto>>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<GetTaskItemsQueryHandler> _logger;

    public GetTaskItemsQueryHandler(ITaskItemRepository taskItemRepository, ILogger<GetTaskItemsQueryHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<PaginatedResult<TaskItemDto>>> Handle(GetTaskItemsQuery request, CancellationToken cancellationToken)
    {
        // Limitar pageSize a maximo 100
        var pageSize = Math.Min(request.PageSize, 100);
        var page = Math.Max(request.Page, 1);

        var taskItems = await _taskItemRepository.GetAllAsync(page, pageSize);
        var totalCount = await _taskItemRepository.GetTotalCountAsync();

        var dtos = taskItems.Select(t => new TaskItemDto
        {
            Id = t.Id,
            Title = t.Title,
            Description = t.Description,
            AssignedTo = t.AssignedTo,
            Status = t.Status,
            EstimatedTime = t.EstimatedTime,
            ActualTime = t.ActualTime,
            EvidenceFileName = t.EvidenceFileName,
            HasEvidence = !string.IsNullOrEmpty(t.EvidenceFilePath),
            CreatedAt = t.CreatedAt,
            UpdatedAt = t.UpdatedAt
        }).ToList();

        var result = new PaginatedResult<TaskItemDto>
        {
            Items = dtos,
            TotalCount = totalCount,
            Page = page,
            PageSize = pageSize
        };

        return ApiResponse<PaginatedResult<TaskItemDto>>.Ok(result);
    }
}
