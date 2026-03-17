using BSC.Application.DTOs;
using MediatR;

namespace BSC.Application.Queries.GetTaskItems;

/// <summary>
/// Query para obtener la lista paginada de tareas.
/// Soporta filtrado por rol y email del usuario.
/// </summary>
public class GetTaskItemsQuery : IRequest<ApiResponse<PaginatedResult<TaskItemDto>>>
{
    public int Page { get; set; } = 1;
    public int PageSize { get; set; } = 20;
    public string? UserEmail { get; set; }
    public string? UserRole { get; set; }
}
