using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MongoDB.Driver;

namespace BSC.Infrastructure.Persistence.Repositories;

/// <summary>
/// Repositorio de adjuntos de resolucion de alertas (MongoDB).
/// Coleccion: alertasResolucionAdjuntos.
/// </summary>
public class AlertaAdjuntoRepository : IAlertaAdjuntoRepository
{
    private const string CollectionName = "alertasResolucionAdjuntos";

    private readonly IMongoCollection<AlertaResolucionAdjunto> _collection;

    public AlertaAdjuntoRepository(MongoDbContext context)
    {
        _collection = context.GetCollection<AlertaResolucionAdjunto>(CollectionName);
        var keys = Builders<AlertaResolucionAdjunto>.IndexKeys
            .Ascending(a => a.IdNotificacion)
            .Ascending(a => a.Fecha);
        _collection.Indexes.CreateOne(new CreateIndexModel<AlertaResolucionAdjunto>(keys));
    }

    public async Task<AlertaResolucionAdjunto> CreateAsync(AlertaResolucionAdjunto adjunto, CancellationToken cancellationToken = default)
    {
        await _collection.InsertOneAsync(adjunto, cancellationToken: cancellationToken);
        return adjunto;
    }

    public async Task<List<AlertaResolucionAdjunto>> GetByIdNotificacionAsync(long idNotificacion, CancellationToken cancellationToken = default)
    {
        var filter = Builders<AlertaResolucionAdjunto>.Filter.Eq(a => a.IdNotificacion, idNotificacion);
        return await _collection.Find(filter).SortBy(a => a.Fecha).ToListAsync(cancellationToken);
    }

    public async Task<AlertaResolucionAdjunto?> GetByIdAsync(string id, CancellationToken cancellationToken = default)
    {
        var filter = Builders<AlertaResolucionAdjunto>.Filter.Eq(a => a.Id, id);
        return await _collection.Find(filter).FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<bool> DeleteAsync(string id, CancellationToken cancellationToken = default)
    {
        var result = await _collection.DeleteOneAsync(
            Builders<AlertaResolucionAdjunto>.Filter.Eq(a => a.Id, id), cancellationToken);
        return result.DeletedCount > 0;
    }
}
