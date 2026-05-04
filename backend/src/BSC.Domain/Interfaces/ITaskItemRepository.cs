using BSC.Domain.Entities;

namespace BSC.Domain.Interfaces;

/// <summary>
/// Puerto de salida para el repositorio de tareas.
/// </summary>
public interface ITaskItemRepository
{
    Task<List<TaskItem>> GetAllAsync(int page, int pageSize, string? search = null, string? status = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null, string? sortBy = null, string? sortDir = null);
    Task<int> GetTotalCountAsync(string? search = null, string? status = null, string? dateFrom = null, string? dateTo = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null);
    Task<List<TaskItem>> GetByLeaderEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null, string? sortBy = null, string? sortDir = null);
    Task<int> GetCountByLeaderEmailAsync(string email, List<string> statuses, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null);
    Task<List<TaskItem>> GetByAssignedEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? sortDueDate = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null, string? sortBy = null, string? sortDir = null);
    Task<int> GetCountByAssignedEmailAsync(string email, List<string> statuses, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFrom = null, string? dateTo = null, string? titleFilter = null, string? assignedToFilter = null, string? leaderFilter = null);
    Task<TaskItem?> GetByIdAsync(string id);
    Task<TaskItem> CreateAsync(TaskItem taskItem);
    Task<TaskItem> UpdateAsync(TaskItem taskItem);
    Task DeleteAsync(string id);
    Task BulkDeleteAsync(List<string> ids);
    Task<List<TaskItem>> GetByCollaboratorNameAsync(string collaboratorName, string? status, DateTime? from, DateTime? to);
    Task<List<TaskItem>> GetByCollaboratorWithHistoricStatusAsync(string collaboratorName, string historicStatus, DateTime? from, DateTime? to);
    Task<List<TaskItem>> GetAllForDashboardAsync(DateTime? from, DateTime? to);
    Task<List<TaskItem>> GetForDashboardByLeaderAsync(string leaderEmail, DateTime? from, DateTime? to);
    Task<List<TaskItem>> GetForDashboardByAssigneeAsync(string assigneeEmail, DateTime? from, DateTime? to);

    /// <summary>
    /// Retorna los valores únicos no vacíos del campo solicitado, restringido por el ámbito del usuario.
    /// field admite: "title", "assignedTo", "leader", "status".
    /// scope: "all" (Gerente/Admin), "leader" (filtra por AssignedLeaderEmail = scopeEmail),
    /// "assignee" (filtra por AssignedToEmail = scopeEmail). statuses: lista a filtrar (visibilidad por rol).
    /// </summary>
    Task<List<string>> GetDistinctFieldValuesAsync(string field, string scope, string? scopeEmail, List<string>? statuses);
}
