using BSC.Domain.Entities;

namespace BSC.Domain.Interfaces;

/// <summary>
/// Puerto de salida para el repositorio del historial de cambios de estado de Alertas.
/// La persistencia es MongoDB (coleccion alertasEstadosHistorial).
/// </summary>
public interface IAlertaHistorialRepository
{
    /// <summary>
    /// Inserta un registro de cambio de estado en el historial.
    /// </summary>
    Task<AlertaEstadoHistorial> CreateAsync(AlertaEstadoHistorial registro, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retorna el historial completo de una notificacion ordenado por fecha DESC.
    /// </summary>
    Task<List<AlertaEstadoHistorial>> GetByIdNotificacionAsync(long idNotificacion, CancellationToken cancellationToken = default);
}
