using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MongoDB.Driver;

namespace BSC.Infrastructure.Persistence.Repositories;

/// <summary>
/// Implementacion del repositorio de configuracion del dashboard BSC con MongoDB.
/// </summary>
public class BscDashboardConfigRepository : IBscDashboardConfigRepository
{
    private readonly IMongoCollection<BscDashboardConfig> _collection;

    public BscDashboardConfigRepository(MongoDbContext context)
    {
        _collection = context.GetCollection<BscDashboardConfig>("BscDashboardConfigs");
    }

    public async Task<BscDashboardConfig?> GetActiveConfigAsync()
    {
        var filter = Builders<BscDashboardConfig>.Filter.Eq(c => c.IsActive, true);
        return await _collection.Find(filter).FirstOrDefaultAsync();
    }
}
