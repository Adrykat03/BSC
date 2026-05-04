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
    public string? Search { get; set; }
    public string? Status { get; set; }
    public string? DateFrom { get; set; } // YYYY-MM-DD
    public string? DateTo { get; set; } // YYYY-MM-DD
    public string? SortDueDate { get; set; } // "asc", "desc" — legado

    // Filtros por columna específica (case-insensitive contains).
    public string? TitleFilter { get; set; }
    public string? AssignedToFilter { get; set; }
    public string? LeaderFilter { get; set; }

    // Ordenamiento genérico.
    // SortBy admite: title, assignedTo, leader, status, dueDate, estimatedTime, rating, createdAt.
    public string? SortBy { get; set; }
    public string? SortDir { get; set; } // "asc", "desc"
}
