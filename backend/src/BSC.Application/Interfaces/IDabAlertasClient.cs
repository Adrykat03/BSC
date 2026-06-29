using System.Text.Json.Nodes;

namespace BSC.Application.Interfaces;

/// <summary>
/// Snapshot de la fila Avisos.notificacionesConsolidadas relevante para el modulo de Alertas.
/// Solo se leen los campos que el handler necesita; el resto se ignora.
/// </summary>
public class NotificacionConsolidadaSnapshot
{
    public long IdNotificacion { get; set; }
    public string Estado { get; set; } = string.Empty;
    public string? NotasResolucion { get; set; }
    public string? UsuarioResolucion { get; set; }
    public DateTime? FechaResolucion { get; set; }
}

/// <summary>
/// Datos a actualizar via DAB (PATCH) en Avisos.notificacionesConsolidadas.
/// FechaResolucion = null cuando se vuelve al estado A; ahora() en otros casos.
/// FechaModificacion = ahora() siempre (auditoria de cualquier cambio).
/// </summary>
public class ActualizarNotificacionRequest
{
    public string Estado { get; set; } = string.Empty;
    public string? NotasResolucion { get; set; }
    public string? UsuarioResolucion { get; set; }
    public DateTime? FechaResolucion { get; set; }
    public DateTime FechaModificacion { get; set; }
}

/// <summary>
/// Configuracion del cliente de DAB. Lee de DabSettings:BaseUrl en appsettings.
/// </summary>
public class DabSettings
{
    public string BaseUrl { get; set; } = string.Empty;
}

/// <summary>
/// Cliente HTTP tipado para Data API Builder (Avisos.notificacionesConsolidadas).
/// DAB expone REST en {BaseUrl}/api/{EntityName}.
/// </summary>
public interface IDabAlertasClient
{
    /// <summary>
    /// Lee el snapshot actual de la notificacion. Retorna null si no existe.
    /// </summary>
    Task<NotificacionConsolidadaSnapshot?> GetByIdAsync(long idNotificacion, CancellationToken cancellationToken = default);

    /// <summary>
    /// PATCH a la notificacion via DAB. Lanza HttpRequestException si DAB falla.
    /// </summary>
    Task ActualizarAsync(long idNotificacion, ActualizarNotificacionRequest request, CancellationToken cancellationToken = default);

    /// <summary>
    /// Lee TODAS las notificaciones de DAB paginando hasta agotar los resultados,
    /// ordenadas por fechaCreacion desc. Devuelve las filas COMPLETAS (passthrough):
    /// cada fila es un <see cref="JsonObject"/> con todos los campos originales de DAB.
    /// Lanza HttpRequestException si DAB falla.
    /// </summary>
    Task<IReadOnlyList<JsonObject>> GetAllAsync(CancellationToken cancellationToken = default);
}
