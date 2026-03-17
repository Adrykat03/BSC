using BSC.Domain.Entities;

namespace BSC.Domain.Interfaces;

/// <summary>
/// Puerto de salida para el repositorio de tareas.
/// </summary>
public interface ITaskItemRepository
{
    Task<List<TaskItem>> GetAllAsync(int page, int pageSize);
    Task<int> GetTotalCountAsync();
    Task<List<TaskItem>> GetByLeaderEmailAsync(string email, int page, int pageSize);
    Task<int> GetCountByLeaderEmailAsync(string email);
    Task<List<TaskItem>> GetByAssignedEmailAsync(string email, List<string> statuses, int page, int pageSize);
    Task<int> GetCountByAssignedEmailAsync(string email, List<string> statuses);
    Task<TaskItem?> GetByIdAsync(string id);
    Task<TaskItem> CreateAsync(TaskItem taskItem);
    Task<TaskItem> UpdateAsync(TaskItem taskItem);
    Task DeleteAsync(string id);
}
