using BSC.Application.DTOs;
using BSC.Application.Mappings;
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
                new List<string> { $"No se encontro una tarea con el ID '{request.Id}'." }
            );
        }

        return ApiResponse<TaskItemDto>.Ok(TaskItemMapper.ToDto(taskItem));
    }
}
