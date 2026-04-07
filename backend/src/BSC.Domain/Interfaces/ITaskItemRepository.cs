using BSC.Domain.Entities;

namespace BSC.Domain.Interfaces;

/// <summary>
/// Puerto de salida para el repositorio de tareas.
/// </summary>
public interface ITaskItemRepository
{
    Task<List<TaskItem>> GetAllAsync(int page, int pageSize, string? search = null, string? status = null, string? dateFilter = null, string? sortDueDate = null);
    Task<int> GetTotalCountAsync(string? search = null, string? status = null, string? dateFilter = null);
    Task<List<TaskItem>> GetByLeaderEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFilter = null, string? sortDueDate = null);
    Task<int> GetCountByLeaderEmailAsync(string email, List<string> statuses, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFilter = null);
    Task<List<TaskItem>> GetByAssignedEmailAsync(string email, List<string> statuses, int page, int pageSize, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFilter = null, string? sortDueDate = null);
    Task<int> GetCountByAssignedEmailAsync(string email, List<string> statuses, string? search = null, List<string>? conditionalStatuses = null, DateTime? visibleBeforeDeadline = null, string? statusFilter = null, string? dateFilter = null);
    Task<TaskItem?> GetByIdAsync(string id);
    Task<TaskItem> CreateAsync(TaskItem taskItem);
    Task<TaskItem> UpdateAsync(TaskItem taskItem);
    Task DeleteAsync(string id);
    Task<List<TaskItem>> GetByCollaboratorNameAsync(string collaboratorName, string? status, DateTime? from, DateTime? to);
    Task<List<TaskItem>> GetByCollaboratorWithHistoricStatusAsync(string collaboratorName, string historicStatus, DateTime? from, DateTime? to);
    Task<List<TaskItem>> GetAllForDashboardAsync(DateTime? from, DateTime? to);
    Task<List<TaskItem>> GetForDashboardByLeaderAsync(string leaderEmail, DateTime? from, DateTime? to);
    Task<List<TaskItem>> GetForDashboardByAssigneeAsync(string assigneeEmail, DateTime? from, DateTime? to);
}
