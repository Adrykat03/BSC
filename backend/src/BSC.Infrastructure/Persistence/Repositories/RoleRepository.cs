using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MongoDB.Driver;

namespace BSC.Infrastructure.Persistence.Repositories;

/// <summary>
/// Implementacion del repositorio de roles con MongoDB.
/// </summary>
public class RoleRepository : IRoleRepository
{
    private readonly IMongoCollection<Role> _collection;

    public RoleRepository(MongoDbContext context)
    {
        _collection = context.GetCollection<Role>("Roles");

        // Crear indice unico en Name para roles no eliminados
        var indexKeysDefinition = Builders<Role>.IndexKeys.Ascending(r => r.Name);
        var indexOptions = new CreateIndexOptions<Role>
        {
            Unique = true,
            PartialFilterExpression = Builders<Role>.Filter.Eq(r => r.IsDeleted, false)
        };
        _collection.Indexes.CreateOneAsync(new CreateIndexModel<Role>(indexKeysDefinition, indexOptions));
    }

    public async Task<List<Role>> GetAllAsync(int page, int pageSize)
    {
        var filter = Builders<Role>.Filter.Eq(r => r.IsDeleted, false);
        var skip = (page - 1) * pageSize;

        return await _collection
            .Find(filter)
            .SortByDescending(r => r.CreatedAt)
            .Skip(skip)
            .Limit(pageSize)
            .ToListAsync();
    }

    public async Task<int> GetTotalCountAsync()
    {
        var filter = Builders<Role>.Filter.Eq(r => r.IsDeleted, false);
        return (int)await _collection.CountDocumentsAsync(filter);
    }

    public async Task<Role?> GetByIdAsync(string id)
    {
        var filter = Builders<Role>.Filter.Eq(r => r.Id, id)
                   & Builders<Role>.Filter.Eq(r => r.IsDeleted, false);
        return await _collection.Find(filter).FirstOrDefaultAsync();
    }

    public async Task<Role?> GetByNameAsync(string name)
    {
        var filter = Builders<Role>.Filter.Eq(r => r.Name, name)
                   & Builders<Role>.Filter.Eq(r => r.IsDeleted, false);
        return await _collection.Find(filter).FirstOrDefaultAsync();
    }

    public async Task<Role> CreateAsync(Role role)
    {
        await _collection.InsertOneAsync(role);
        return role;
    }

    public async Task<Role> UpdateAsync(Role role)
    {
        var filter = Builders<Role>.Filter.Eq(r => r.Id, role.Id);
        await _collection.ReplaceOneAsync(filter, role);
        return role;
    }

    public async Task DeleteAsync(string id)
    {
        var filter = Builders<Role>.Filter.Eq(r => r.Id, id);
        var update = Builders<Role>.Update
            .Set(r => r.IsDeleted, true)
            .Set(r => r.DeletedAt, DateTime.UtcNow);
        await _collection.UpdateOneAsync(filter, update);
    }
}
