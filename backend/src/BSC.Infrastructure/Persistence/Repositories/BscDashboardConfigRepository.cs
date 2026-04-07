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

    public async Task SeedIfEmptyAsync()
    {
        var existing = await _collection.Find(_ => true).FirstOrDefaultAsync();
        if (existing != null) return;

        var now = DateTime.UtcNow;
        await _collection.InsertOneAsync(new BscDashboardConfig
        {
            Emails = new List<string>
            {
                "isabella.sanchez@kfc.com.ec",
                "manuel.zapata@kfc.com.ec"
            },
            TaskTitlePattern = "Proceso mensual liquidaciones",
            IsActive = true,
            CreatedAt = now,
            UpdatedAt = now
        });
    }
}
