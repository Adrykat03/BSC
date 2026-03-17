using BSC.Application.DTOs;
using BSC.Domain.Interfaces;
using MediatR;
using Microsoft.Extensions.Logging;

namespace BSC.Application.Commands.DeleteTaskItem;

/// <summary>
/// Handler para el comando de eliminacion de tarea.
/// </summary>
public class DeleteTaskItemCommandHandler : IRequestHandler<DeleteTaskItemCommand, ApiResponse<object>>
{
    private readonly ITaskItemRepository _taskItemRepository;
    private readonly ILogger<DeleteTaskItemCommandHandler> _logger;

    public DeleteTaskItemCommandHandler(ITaskItemRepository taskItemRepository, ILogger<DeleteTaskItemCommandHandler> logger)
    {
        _taskItemRepository = taskItemRepository;
        _logger = logger;
    }

    public async Task<ApiResponse<object>> Handle(DeleteTaskItemCommand request, CancellationToken cancellationToken)
    {
        var taskItem = await _taskItemRepository.GetByIdAsync(request.Id);
        if (taskItem == null)
        {
            return ApiResponse<object>.Fail(
                "Tarea no encontrada.",
                new List<string> { $"No se encontró una tarea con el ID '{request.Id}'." }
            );
        }

        await _taskItemRepository.DeleteAsync(request.Id);

        _logger.LogInformation("Tarea eliminada exitosamente: {Title} ({TaskId})", taskItem.Title, taskItem.Id);

        return ApiResponse<object>.Ok(null, "Tarea eliminada exitosamente.");
    }
}
