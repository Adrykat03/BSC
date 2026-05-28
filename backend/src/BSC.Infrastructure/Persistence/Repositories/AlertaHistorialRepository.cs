using BSC.Domain.Entities;
using BSC.Domain.Interfaces;
using MongoDB.Driver;

namespace BSC.Infrastructure.Persistence.Repositories;

/// <summary>
/// Implementacion del repositorio del historial de alertas con MongoDB.
/// Coleccion: alertasEstadosHistorial.
/// </summary>
public class AlertaHistorialRepository : IAlertaHistorialRepository
{
    private const string CollectionName = "alertasEstadosHistorial";

    private readonly IMongoCollection<AlertaEstadoHistorial> _collection;

    public AlertaHistorialRepository(MongoDbContext context)
    {
        _collection = context.GetCollection<AlertaEstadoHistorial>(CollectionName);
        EnsureIndexes();
    }

    private void EnsureIndexes()
    {
        // Indice por idNotificacion + fecha desc para acelerar GET historial.
        var keys = Builders<AlertaEstadoHistorial>.IndexKeys
            .Ascending(h => h.IdNotificacion)
            .Descending(h => h.Fecha);
        _collection.Indexes.CreateOne(new CreateIndexModel<AlertaEstadoHistorial>(keys));
    }

    public async Task<AlertaEstadoHistorial> CreateAsync(AlertaEstadoHistorial registro, CancellationToken cancellationToken = default)
    {
        await _collection.InsertOneAsync(registro, cancellationToken: cancellationToken);
        return registro;
    }

    public async Task<List<AlertaEstadoHistorial>> GetByIdNotificacionAsync(long idNotificacion, CancellationToken cancellationToken = default)
    {
        var filter = Builders<AlertaEstadoHistorial>.Filter.Eq(h => h.IdNotificacion, idNotificacion);
        return await _collection
            .Find(filter)
            .SortByDescending(h => h.Fecha)
            .ToListAsync(cancellationToken);
    }
}
