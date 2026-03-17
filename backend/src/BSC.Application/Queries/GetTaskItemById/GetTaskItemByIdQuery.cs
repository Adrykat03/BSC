using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Queries.GetTaskItemById;

/// <summary>
/// Query para obtener una tarea por su ID.
/// </summary>
public class GetTaskItemByIdQuery : IRequest<ApiResponse<TaskItemDto>>
{
    public string Id { get; set; } = string.Empty;
}
