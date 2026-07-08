using BSC.Domain.Entities;

namespace BSC.Domain.Interfaces;

/// <summary>
/// Puerto de salida para los adjuntos de resolucion de Alertas.
/// Persistencia: MongoDB (coleccion alertasResolucionAdjuntos); archivos en disco.
/// </summary>
public interface IAlertaAdjuntoRepository
{
    Task<AlertaResolucionAdjunto> CreateAsync(AlertaResolucionAdjunto adjunto, CancellationToken cancellationToken = default);

    /// <summary>Adjuntos de una notificacion, ordenados por fecha ASC (mas antiguo primero).</summary>
    Task<List<AlertaResolucionAdjunto>> GetByIdNotificacionAsync(long idNotificacion, CancellationToken cancellationToken = default);

    Task<AlertaResolucionAdjunto?> GetByIdAsync(string id, CancellationToken cancellationToken = default);

    Task<bool> DeleteAsync(string id, CancellationToken cancellationToken = default);
}
