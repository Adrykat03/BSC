using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Queries.GetTaskItems;

/// <summary>
/// Query para obtener la lista paginada de tareas.
/// </summary>
public class GetTaskItemsQuery : IRequest<ApiResponse<PaginatedResult<TaskItemDto>>>
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
}
