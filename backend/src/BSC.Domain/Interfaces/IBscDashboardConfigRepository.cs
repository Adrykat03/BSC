using BSC.Domain.Entities;

namespace BSC.Domain.Interfaces;

/// <summary>
/// Interfaz de repositorio para la configuracion del dashboard BSC.
/// </summary>
public interface IBscDashboardConfigRepository
{
    Task<BscDashboardConfig?> GetActiveConfigAsync();
    Task SeedIfEmptyAsync();
}
