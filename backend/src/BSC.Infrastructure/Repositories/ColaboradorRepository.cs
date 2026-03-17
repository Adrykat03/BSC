using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using BSC.Infrastructure.Persistence;
using MongoDB.Driver;

namespace BSC.Infrastructure.Repositories;

public class ColaboradorRepository : IColaboradorRepository
{
    private readonly IMongoCollection<Colaborador> _collection;

    public ColaboradorRepository(MongoDbContext context)
    {
        _collection = context.GetCollection<Colaborador>("Colaboradores");
    }

    public async Task<List<Colaborador>> GetAllAsync()
    {
        var filter = Builders<Colaborador>.Filter.Eq(c => c.IsDeleted, false);
        return await _collection.Find(filter).ToListAsync();
    }

    public async Task<Colaborador?> GetByIdAsync(string id)
    {
        var filter = Builders<Colaborador>.Filter.Eq(c => c.Id, id);
        return await _collection.Find(filter).FirstOrDefaultAsync();
    }

    public async Task<Colaborador?> GetByCedulaAsync(string cedula)
    {
        var filter = Builders<Colaborador>.Filter.Eq(c => c.Cedula, cedula)
                     & Builders<Colaborador>.Filter.Eq(c => c.IsDeleted, false);
        return await _collection.Find(filter).FirstOrDefaultAsync();
    }

    public async Task<Colaborador?> GetByCorreoAsync(string correo)
    {
        var filter = Builders<Colaborador>.Filter.Eq(c => c.Correo, correo)
                     & Builders<Colaborador>.Filter.Eq(c => c.IsDeleted, false);
        return await _collection.Find(filter).FirstOrDefaultAsync();
    }

    public async Task CreateAsync(Colaborador colaborador)
    {
        await _collection.InsertOneAsync(colaborador);
    }

    public async Task UpdateAsync(Colaborador colaborador)
    {
        var filter = Builders<Colaborador>.Filter.Eq(c => c.Id, colaborador.Id);
        await _collection.ReplaceOneAsync(filter, colaborador);
    }

    public async Task DeleteAsync(string id)
    {
        var filter = Builders<Colaborador>.Filter.Eq(c => c.Id, id);
        var update = Builders<Colaborador>.Update
            .Set(c => c.IsDeleted, true)
            .Set(c => c.DeletedAt, DateTime.UtcNow);
        await _collection.UpdateOneAsync(filter, update);
    }
}
