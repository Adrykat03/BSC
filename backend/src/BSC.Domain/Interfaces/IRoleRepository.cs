using BSC.Domain.Entities;

namespace BSC.Domain.Interfaces;

/// <summary>
/// Puerto de salida para el repositorio de roles.
/// </summary>
public interface IRoleRepository
{
    Task<List<Role>> GetAllAsync(int page, int pageSize);
    Task<int> GetTotalCountAsync();
    Task<Role?> GetByIdAsync(string id);
    Task<Role?> GetByNameAsync(string name);
    Task<Role> CreateAsync(Role role);
    Task<Role> UpdateAsync(Role role);
    Task DeleteAsync(string id);
}
